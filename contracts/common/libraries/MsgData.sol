// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library MsgData {
	function valueAt(uint256 ptr) internal pure returns (bytes32 value) {
		assembly {
			value := calldataload(ptr)
		}
	}
}
