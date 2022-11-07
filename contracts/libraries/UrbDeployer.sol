// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library UrbDeployer {
	/// Compute contract address, deployed by address with nonce
	/// @notice nonce should be in range (0, 0x7f]
	function getAddress(address self, uint256 nonce) internal pure returns (address addr) {
		require(nonce != 0 && nonce <= 0x7f, "UrbDeployer: invalid nonce");
		assembly {
			let ptr := mload(0x40)
			mstore(ptr, or(or(0xd694000000000000000000000000000000000000000000, shl(0x8, self)), nonce))
			addr := keccak256(add(ptr, 0xa), 0x17)
		}
	}
}
