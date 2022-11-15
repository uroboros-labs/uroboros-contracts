// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "../../common/libraries/Hex.sol";

library UrbDeployer {
	/// Compute contract address, deployed by address with nonce
	/// @notice nonce should be in range (0, 0x7f]
	function getAddress(address self, uint256 nonce) internal view returns (address addr) {
		require(nonce != 0 && nonce <= 0x7f, "UrbDeployer: invalid nonce");
		uint256 value;
		assembly {
			value := or(or(0xd694000000000000000000000000000000000000000000, shl(0x8, self)), nonce)
			let ptr := mload(0x40)
			mstore(ptr, value)
			addr := keccak256(add(ptr, 0x9), 0x17)
			mstore(ptr, 0x0)
		}
		require(addr.code.length != 0, "UrbDeployer: contract not deployed");
	}
}