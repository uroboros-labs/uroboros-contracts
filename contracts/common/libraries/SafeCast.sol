// SPDX-License-Identifier: MIT
pragma solidity >=0.8.15;

library SafeCast {
	function toLeAddress(bytes32 self) internal pure returns (address x) {
		assembly {
			x := shr(0x60, self)
		}
	}

	function toAddress(bytes32 self) internal pure returns (address x) {
		assembly ("memory-safe") {
			x := self
		}
	}

	function toUint(bytes32 self) internal pure returns (uint256 x) {
		assembly {
			x := self
		}
	}
}
