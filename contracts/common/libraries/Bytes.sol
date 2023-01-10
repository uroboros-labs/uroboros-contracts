// SPDX-License-Identifier: No license
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
		assembly {
			value := calldataload(add(self.offset, ptr))
		}
	}

	function isZero(bytes memory self) internal pure returns (bool x) {
		assembly {
			x := iszero(self)
		}
	}
}
