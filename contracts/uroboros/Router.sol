// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import {Route} from './libraries/Route.sol';
import {Part} from './libraries/Part.sol';

// DEV_ONLY
import './libraries/Strings2.sol';
import 'hardhat/console.sol';

contract Router {
	using SafeERC20 for IERC20;
	using Part for Route.Part;
	using Math for uint;

	/// @dev DEV_ONLY
	using Strings for *;
	using Strings2 for *;

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
		try this._swap(route, amounts, desc, msg.sender) returns (uint[] memory _amounts) {
			amounts = _amounts;
		} catch Error(string memory reason) {
			revert(reason);
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
		amounts = new uint[](route.length);
		// todo free totals
		uint[][] memory totals;
		{
			uint tokenMaxId;
			for (uint i; i < route.length; i++) {
				Route.Part memory part = route[i];
				tokenMaxId = tokenMaxId.max(part.tokenInId());
				tokenMaxId = tokenMaxId.max(part.tokenOutId());
			}
			totals = new uint[][](tokenMaxId + 1);
		}
		for (uint i; i < totals.length; i++) {
			totals[i] = new uint[](route.length);
		}
		for (uint i; i < route.length; ) {
			Route.Part memory part = route[i];
			uint tokenInId = part.tokenInId();
			uint tokenOutId = part.tokenOutId();
			uint totalAmountIn;
			uint totalAmountOut;
			for (uint j; j < i; j++) {
				if (skipMask & route[j].sectionId() == 0) {
					uint tmp;
					if ((tmp = totals[tokenInId][j]) != 0) totalAmountIn = tmp;
					if ((tmp = totals[tokenOutId][j]) != 0) totalAmountOut = tmp;
				}
			}
			uint amountIn = totalAmountIn;
			if (part.amountIn > totalAmountIn) {
				totalAmountIn = amountIn = part.amountIn;
				require(part.isInput(), 'quote: insufficient input');
			}
			uint amountOut = part.quote(amountIn);
			totals[tokenInId][i] = totalAmountIn - amountIn;
			totals[tokenOutId][i] = totalAmountOut + amountOut;
			amounts[i] = amountOut;
			if (amountOut < part.amountOutMin) {
				skipMask |= part.sectionId();
				i = part.sectionEnd();
			} else {
				i++;
			}
		}
		console.log(totals.toString());
	}

	modifier onlySelf() {
		require(msg.sender == address(this));
		_;
	}

	/// @notice FOR INTERNAL USE ONLY - Route.Part contains unsafe function pointers
	function _swap(
		Route.Part[] calldata route,
		uint[] memory amounts,
		SectionDesc memory desc,
		address sender
	) external onlySelf returns (uint[] memory) {
		while (desc.start < desc.end) {
			Route.Part calldata part = route[desc.start];
			if (desc.skipMask & part.sectionId() != 0) {
				desc.start = part.sectionEnd();
			}
			uint sectionDepth = part.sectionDepth();
			if (sectionDepth > desc.depth) {
				desc.depth = sectionDepth;
				desc.end = part.sectionEnd();
				try this._swap(route, amounts, desc, sender) returns (uint[] memory _amounts) {
					amounts = _amounts;
				} catch Error(string memory reason) {
					revert(reason);
				} catch (bytes memory data) {
					// decode return-reverted amounts
					amounts = abi.decode(data, (uint[]));
				}
			} else {
				uint amountIn = part.amountIn;
				uint balance = part.tokenIn.balanceOf(address(this));
				if (amountIn == 0) {
					amountIn = balance;
				} else if (amountIn > balance) {
					require(part.isInput(), 'swap: insufficient input');
					part.tokenIn.safeTransferFrom(sender, address(this), amountIn - balance);
				}
				address to = part.isOutput() ? sender : address(this);
				balance = part.tokenOut.balanceOf(to);
				part.swap(amountIn, to);
				uint postBalance = part.tokenOut.balanceOf(to);
				amounts[desc.start] = postBalance - balance;
				if (postBalance < balance + part.amountOutMin) {
					// return-revert amounts
					_revertWith(amounts);
				}
				desc.start++;
			}
		}
		return amounts;
	}

	function _revertWith(uint[] memory values) internal pure {
		bytes memory data = abi.encode(values);
		assembly ('memory-safe') {
			let size := mload(data)
			let offset := add(data, 0x20)
			revert(offset, size)
		}
	}
}
