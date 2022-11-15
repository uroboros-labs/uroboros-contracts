// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library SafeCast {
	function toAddress(bytes32 self) internal pure returns (address x) {
		assembly {
			x := and(self, sub(0x0, 0x1))
		}
	}

	function toUint(bytes32 self) internal pure returns (uint256 x) {
		assembly {
			x := self
		}
	}
}
