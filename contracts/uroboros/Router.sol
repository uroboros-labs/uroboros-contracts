// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {Route} from "./libraries/Route.sol";
import {Part} from "./libraries/Part.sol";

contract Router {
	using SafeERC20 for IERC20;
	using Part for Route.Part;
	using Math for uint;

	struct SectionDesc {
		uint start;
		uint end;
		uint depth;
		uint skipMask;
	}

	function swap(
		bytes calldata payload
	) external returns (uint[] memory amounts, uint skipMask, uint gasUsed) {
		gasUsed = gasleft();
		Route.Part[] memory route = Route.decode(payload);
		(amounts, skipMask) = _quote(route);
		SectionDesc memory desc;
		desc.end = route.length;
		desc.skipMask = skipMask;
		try this._swap(route, amounts, desc) returns (uint[] memory _amounts) {
			amounts = _amounts;
		} catch (bytes memory data) {
			// decode return-reverted amounts
			amounts = abi.decode(data, (uint[]));
		}
		gasUsed -= gasleft();
	}

	function quote(bytes calldata payload) external view returns (uint[] memory, uint) {
		Route.Part[] memory route = Route.decode(payload);
		return _quote(route);
	}

	function _quote(
		Route.Part[] memory route
	) internal view returns (uint[] memory amounts, uint skipMask) {
		uint[][] memory totals;
		{
			uint tokenMaxId;
			for (uint i; i < route.length; i++) {
				Route.Part memory part = route[i];
				tokenMaxId = tokenMaxId.max(part.tokenInId());
				tokenMaxId = tokenMaxId.max(part.tokenInId());
			}
			totals = new uint[][](tokenMaxId);
		}
		for (uint i; i < totals.length; i++) {
			totals[i] = new uint[](route.length);
		}
		for (uint i; i < route.length; ) {
			Route.Part memory part;
			uint tokenInId = part.tokenInId();
			uint tokenOutId = part.tokenOutId();
			uint totalAmountIn;
			uint totalAmountOut;
			for (uint j; j < i; j++) {
				part = route[j];
				if (skipMask & part.sectionId() == 0) {
					uint tmp;
					if ((tmp = totals[tokenInId][j]) != 0) totalAmountIn = tmp;
					if ((tmp = totals[tokenOutId][j]) != 0) totalAmountOut = tmp;
				}
			}
			part = route[i];
			require(part.amountIn <= totalAmountIn || part.isInput(), "quote: insufficient input");
			uint amountIn = part.amountIn.min(totalAmountIn);
			uint amountOut = part.quote(amountIn);
			totals[tokenInId][i] -= amountIn;
			totals[tokenOutId][i] += amountOut;
			amounts[i] = amountOut;
			if (amountOut < part.amountOutMin) {
				skipMask |= part.sectionId();
				i = part.sectionEnd();
			} else {
				i++;
			}
		}
	}

	modifier onlySelf() {
		require(msg.sender == address(this));
		_;
	}

	/// @notice FOR INTERNAL USE ONLY - Route.Part contains unsafe function pointers
	function _swap(
		Route.Part[] calldata route,
		uint[] memory amounts,
		SectionDesc memory desc
	) external onlySelf returns (uint[] memory) {
		while (desc.start < desc.end) {
			Route.Part calldata part = route[desc.start];
			if (desc.skipMask & part.sectionId() != 0) {
				desc.start += part.sectionEnd();
			}
			uint sectionDepth = part.sectionDepth();
			if (sectionDepth > desc.depth) {
				desc.depth = sectionDepth;
				desc.end = part.sectionEnd();
				try this._swap(route, amounts, desc) returns (uint[] memory _amounts) {
					amounts = _amounts;
				} catch (bytes memory data) {
					// decode return-reverted amounts
					amounts = abi.decode(data, (uint[]));
				}
			} else {
				uint amountIn = part.amountIn != 0
					? part.amountIn
					: IERC20(part.tokenIn).balanceOf(address(this));
				address to = part.isOutput() ? msg.sender : address(this);
				uint preBalance = IERC20(part.tokenOut).balanceOf(to);
				part.swap(amountIn, to);
				uint postBalance = IERC20(part.tokenOut).balanceOf(to);
				amounts[desc.start] = postBalance - preBalance;
				if (postBalance < preBalance + part.amountOutMin) {
					// return-revert amounts
					bytes memory data = abi.encode(amounts);
					assembly ("memory-safe") {
						let size := mload(data)
						let offset := add(data, 0x20)
						revert(offset, size)
					}
				}
				desc.start++;
			}
		}
		return amounts;
	}
}
