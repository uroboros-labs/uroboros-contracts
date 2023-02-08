// SPDX-License-Identifier: No License
pragma solidity >=0.8.17;

import "../../common/libraries/SafeCast.sol";
import "../../common/libraries/Bytes.sol";
import "../../common/libraries/Bits.sol";
import "../adaptors/UniswapV2Adaptor.sol";

library Route {
	using SafeCast for bytes32;
	using Bytes for bytes;
	using Bits for uint;

	enum Adaptor {
		UniswapV2
	}

	struct Part {
		address tokenIn;
		address tokenOut;
		uint amountIn;
		uint amountOutMin;
		// can parse data to adaptor-compatible format (messing with abi encoding)
		// or store calldata ptr for zero-cost (messing with abi encoding a lot)
		// + data may be repeated (add marker) (todo)
		bytes data;
		uint _flags; // contains non-loaded values: sectionId, ...
		// external calls MUST be performed to SAME CONTRACT
		// can also be packed to _flags
		uint _quotePtr;
		uint _swapPtr;
	}

	function decode(bytes calldata payload) internal pure returns (Part[] memory route) {
		uint length = payload.valueAt(0).toUint();
		route = new Part[](length);
		for (uint i; i < length; i++) {
			Part memory part = route[i];
			uint value = payload.valueAt((i + 1) * 32).toUint();
			part.tokenIn = payload.valueAt(value.getBits(0, 16)).toAddress();
			part.tokenOut = payload.valueAt(value.getBits(16, 16)).toAddress();
			uint ptr;
			if ((ptr = value.getBits(32, 16)) != 0) {
				part.amountIn = payload.valueAt(ptr).toUint();
			}
			if ((ptr = value.getBits(48, 16)) != 0) {
				part.amountOutMin = payload.valueAt(ptr).toUint();
			}
			{
				uint tmp = value.getBits(64, 8);
				require(tmp <= uint(type(Adaptor).max), "invalid adaptor");
				Adaptor adaptor = Adaptor(tmp);
				function(address, uint, bytes memory) view returns (uint) quote;
				function(address, uint, bytes memory, address) swap;
				if (adaptor == Adaptor.UniswapV2) {
					quote = UniswapV2Adaptor.quote;
					swap = UniswapV2Adaptor.swap;
				}
				uint quotePtr;
				uint swapPtr;
				assembly ("memory-safe") {
					quotePtr := quote
					swapPtr := swap
				}
				part._quotePtr = quotePtr;
				part._swapPtr = swapPtr;
			}
			// data duplicates:
			// if dataStart == 0, then dataEnd contains index (<i) that points to part with data
			uint dataStart = value.getBits(72, 16);
			uint dataEnd = value.getBits(88, 16);
			part.data = payload.slice(dataStart, dataEnd);
			part._flags = value.getBits(104, 40);
		}
		return route;
	}
}
