// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library TokenId {
	function toPtr(uint256 self) internal pure returns (uint256) {
		return self * 0x14;
	}
}
