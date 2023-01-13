// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

library BitMap {
	function set(uint256 self, uint256 bit) internal pure returns (uint256) {
		return self | (0x1 << bit);
	}

	function get(uint256 self, uint256 bit) internal pure returns (bool) {
		return self & (0x1 << bit) != 0x0;
	}
}
