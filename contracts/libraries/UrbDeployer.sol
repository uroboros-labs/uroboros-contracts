// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library UrbDeployer {
	function getAddress(address self, uint256 nonce) internal pure returns (address addr) {
		require(nonce != 0 && nonce <= 0x7f, "UrbDeployer: invalid nonce");
		assembly {
			let ptr := mload(0x40)
			mstore(ptr, or(or(0xd694, self), nonce)) // todo shifts
			addr := keccak256(ptr, 0x17)
		}
	}
}
