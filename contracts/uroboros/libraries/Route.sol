// SPDX-License-Identifier: No License
pragma solidity >=0.8.17;

import "./UrbDeployer.sol";
import "../../common/libraries/Bytes.sol";

library Route {
	using Bytes for bytes;
	using UrbDeployer for address;

	enum Adaptor {
		UniswapV2
	}

	struct Part {
		address tokenIn;
		address tokenOut;
		uint amountIn;
		uint amountOutMin;
		address adaptor;
		bytes adaptorData;
		uint sectionId;
		uint sectionDepth;
		uint sectionEnd;
		bool isInput;
		bool isOutput;
		uint _flags; // contains
		function(address, uint, bytes memory) returns (uint) quote;
		function(address, uint, bytes memory, address) swap;
	}

	function shift_mask(uint value, uint size) private pure returns (uint, uint) {
		return (value >> size, value & ((0x1 << size) - 0x1));
	}

	function decode(bytes calldata payload) internal pure returns (Part[] memory route) {
		uint offset;
		uint value = uint(payload.valueAt(offset));
		offset += 0x20;
		uint temp;
		(value, temp) = shift_mask(value, 0x8);
		route = new Part[](temp);
		(value, temp) = shift_mask(value, 0xa0);
		address deployer = address(uint160(temp));
		for (uint i; i < route.length; i++) {
			Part memory part = route[i];
			value = uint(payload.valueAt(offset));
			(value, temp) = shift_mask(value, 0x10);
			part.tokenIn = address(bytes20(payload.valueAt(temp)));
			(value, temp) = shift_mask(value, 0x10);
			part.tokenOut = address(bytes20(payload.valueAt(temp)));
			(value, temp) = shift_mask(value, 0x10);
			if (temp != 0x0) part.amountIn = uint(payload.valueAt(temp));
			(value, temp) = shift_mask(value, 0x10);
			if (temp != 0x0) part.amountOutMin = uint(payload.valueAt(temp));
			(value, temp) = shift_mask(value, 0x8);
			part.adaptor = deployer.getAddress(temp);
			(value, temp) = shift_mask(value, 0x10);
			uint temp2;
			(value, temp2) = shift_mask(value, 0x10);
			part.adaptorData = payload.slice(temp, temp2);
			(value, part.sectionId) = shift_mask(value, 0x8);
			(value, part.sectionDepth) = shift_mask(value, 0x8);
			(value, part.sectionEnd) = shift_mask(value, 0x8);
			(value, temp) = shift_mask(value, 0x8);
			part.isInput = temp != 0x0;
			(value, temp) = shift_mask(value, 0x8);
			part.isOutput = temp != 0x0;
			offset += 0x20;
		}
		return route;
	}

	function decodeYul(bytes calldata payload) internal pure returns (Part[] memory route) {
		assembly ("memory-safe") {
			function allocate(size) -> ptr {
				ptr := mload(0x40)
				mstore(0x40, add(ptr, size))
			}

			function allocate_array(length) -> ptr {
				ptr := allocate(mul(add(length, 0x1), 0x20))
			}

			function index_array(ptr, index) -> item_ptr {
				let length := mload(ptr)
				if gt(index, length) {
					// revert
				}
				item_ptr := add(ptr, mul(0x20, add(index, 0x1)))
			}

			function shift_mask(x, s) -> y, z {
				y := shr(s, x)
				z := and(x, sub(shl(s, 0x1), 0x1))
			}

			let value := calldataload(payload.offset)
			let length, deployer, tmp, offset
			value, length := shift_mask(value, 0x8)
			route := allocate_array(length)
			value, deployer := shift_mask(value, 0xa0)

			for {
				let i := 0x0
			} lt(i, length) {
				i := add(i, 0x1)
			} {
				let part := index_array(route, i)
				mstore(part, allocate(352)) // Part size
				value := calldataload(add(payload.offset, offset))

				// amountIn
				value, tmp := shift_mask(value, 0x10)
				tmp := calldataload(add(payload.offset, tmp))
				mstore(part, tmp)
				part := add(part, 0x20)

				offset := add(offset, 0x20)
			}
		}
	}
}
