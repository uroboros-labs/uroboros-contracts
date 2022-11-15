// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library Bytes {
	function valueAt(bytes calldata self, uint256 ptr) internal pure returns (bytes32 value) {
		assembly {
			value := calldataload(add(self.offset, ptr))
		}
	}
}
