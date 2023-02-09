// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./math/Math.sol";

library Bytes {
	error OutOfBounds();

	function valueAtMem(bytes memory self, uint ptr) internal pure returns (bytes32 value) {
		ptr += 32;
		assembly {
			value := mload(add(self, ptr))
		}
	}

	function valueAt(bytes calldata self, uint256 ptr) internal pure returns (bytes32 value) {
		assembly ("memory-safe") {
			ptr := add(ptr, self.offset)
		}
		require(ptr < msg.data.length, "out of bounds");
		assembly ("memory-safe") {
			value := calldataload(ptr)
		}
	}

	function slice(
		bytes calldata data,
		uint start,
		uint end
	) internal pure returns (bytes calldata) {
		require(start <= end, "negative length slice");
		return data[start:end];
	}

	function isZero(bytes memory self) internal pure returns (bool x) {
		assembly {
			x := iszero(self)
		}
	}
}
