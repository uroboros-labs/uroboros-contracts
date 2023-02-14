// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {Route} from './libraries/Route.sol';
import {Part} from './libraries/Part.sol';

// DEV_ONLY
import './libraries/Strings2.sol';
import 'hardhat/console.sol';

contract Router {
	using SafeERC20 for IERC20;
	using Part for Route.Part;
	using Math for uint;
	using SafeMath for uint;

	/// @dev DEV_ONLY
	using Strings for *;
	using Strings2 for *;
	// using StringBuf for StringBuf._StringBuf;

	struct SwapState {
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
		SwapState memory state;
		state.end = route.length;
		state.skipMask = skipMask;
		amounts = _trySwap(route, amounts, state, msg.sender);
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
		uint[][] memory totals2d = _newTotals2d(route);

		for (uint i; i < route.length; ) {
			Route.Part memory part = route[i];
			uint[] memory totalsIn = totals2d[part.tokenInId()];
			uint[] memory totalsOut = totals2d[part.tokenOutId()];

			// todo use total(In/Out)Id to index totalAmount (instead of part index)
			// this just squeezes unused partIds in totalIns array (token is unused in part)
			// how to do reverse-mapping? (id -> isSkipped)
			(uint totalIn, uint totalOut) = _findTotals(route, totalsIn, totalsOut, skipMask, i);
			uint amountIn = totalIn;
			if (part.amountIn > totalIn) {
				totalIn = amountIn = part.amountIn;
				require(part.isInput(), 'quote: insufficient input');
			}

			// part.amountIn == 0 => amountIn = totalIn
			// part.amountIn < totalIn => amountIn = part.amountIn
			// part.amountIn > totalIn => totalIn = amountIn = part.amountIn
			uint amountOut = part.quote(amountIn);
			totalsIn[i] = totalIn.sub(amountIn);
			totalsOut[i] = totalOut.add(amountOut);
			amounts[i] = amountOut;

			if (amountOut < part.amountOutMin) {
				// sectionId should be 2^n, but now stored in uint8, thus capped at 8
				// todo: mask is computed with: 1 << sectionId
				skipMask |= part.sectionId();
				i = part.sectionEnd();
			} else {
				i++;
			}
		}
		console.log(totals2d.toString());
	}

	function _findTotals(
		Route.Part[] memory route,
		uint[] memory totalsIn,
		uint[] memory totalsOut,
		uint skipMask,
		uint i
	) internal pure returns (uint totalIn, uint totalOut) {
		for (uint j; j < i; j++) {
			if (skipMask & route[j].sectionId() == 0) {
				uint tmp;
				if ((tmp = totalsIn[j]) != 0) totalIn = tmp;
				if ((tmp = totalsOut[j]) != 0) totalOut = tmp;
			}
		}
	}

	function _newTotals2d(Route.Part[] memory route) internal pure returns (uint[][] memory) {
		uint[][] memory totals2d;
		uint tokenMaxId;
		for (uint i; i < route.length; i++) {
			Route.Part memory part = route[i];
			tokenMaxId = tokenMaxId.max(part.tokenInId());
			tokenMaxId = tokenMaxId.max(part.tokenOutId());
		}
		totals2d = new uint[][](tokenMaxId + 1);
		for (uint i; i < totals2d.length; i++) {
			totals2d[i] = new uint[](route.length);
		}
		return totals2d;
	}

	function _trySwap(
		Route.Part[] memory route,
		uint[] memory amounts,
		SwapState memory state,
		address sender
	) internal returns (uint[] memory) {
		try this._swap(route, amounts, state, sender) returns (uint[] memory _amounts) {
			return _amounts;
		} catch Error(string memory reason) {
			revert(reason);
		} catch (bytes memory data) {
			// decode return-reverted amounts
			return abi.decode(data, (uint[]));
		}
	}

	function _revertWith(uint[] memory values) internal pure {
		bytes memory data = abi.encode(values);
		assembly ('memory-safe') {
			let size := mload(data)
			let offset := add(data, 0x20)
			revert(offset, size)
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
		SwapState memory state,
		address sender
	) external onlySelf returns (uint[] memory) {
		while (state.start < state.end) {
			Route.Part calldata part = route[state.start];
			if (state.skipMask & part.sectionId() != 0) {
				state.start = part.sectionEnd();
				continue;
			}
			uint sectionDepth = part.sectionDepth();
			if (sectionDepth > state.depth) {
				state.depth = sectionDepth;
				state.end = part.sectionEnd();
				amounts = _trySwap(route, amounts, state, sender);
			} else {
				uint amountIn = part.amountIn;
				uint balance = part.tokenIn.balanceOf(address(this));
				if (amountIn == 0) {
					amountIn = balance;
				} else if (amountIn > balance) {
					require(part.isInput(), 'swap: insufficient input');
					// todo: recipient
					part.tokenIn.safeTransferFrom(sender, address(this), amountIn.sub(balance));
				}
				address to = part.isOutput() ? sender : address(this);
				balance = part.tokenOut.balanceOf(to);
				part.swap(amountIn, to);
				uint postBalance = part.tokenOut.balanceOf(to);
				uint amountOut = postBalance.sub(balance, 'Router: balance decreased');
				amounts[state.start] = postBalance.sub(balance);
				if (amountOut < part.amountOutMin) {
					// return-revert amounts
					_revertWith(amounts);
				}
				state.start++;
			}
		}
		return amounts;
	}
}
