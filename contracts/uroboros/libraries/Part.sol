// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "./UrbDeployer.sol";

library Part {
	/// Amount in ptr
	/// @notice if zero, no amount provided
	function amountInPtr(uint256 self) internal pure returns (uint256) {
		return self & 0xffff;
	}

	/// Amount out min ptr
	/// @notice if zero, no amount provided
	function amountOutMinPtr(uint256 self) internal pure returns (uint256) {
		return (self >> 0x10) & 0xffff;
	}

	/// Unique token id
	/// @dev used to get pointer to token
	function tokenInId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x20) & 0xff;
	}

	/// Unique token id
	/// @dev used to get pointer to token
	function tokenOutId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x28) & 0xff;
	}

	/// Adaptor id
	/// @dev used to compute adaptor address: keccak256(rlp([deployer, nonce]))
	function adaptorId(uint256 self) internal pure returns (uint256) {
		// console.log("adaptorId: %s", (self >> 0x20) & 0xff);
		// return (self >> 0x20) & 0xff;
		return (self >> 0x30) & 0x7f; // adaptorId <= 0x7f;
	}

	/// Data start
	/// @dev used to get data slice for adaptor: data[dataStart:dataEnd]
	function dataStart(uint256 self) internal pure returns (uint256) {
		// console.log("dataStart: %s", (self >> 0x28) & 0xffff);
		return (self >> 0x38) & 0xffff;
	}

	/// Data end
	/// @dev used to get data slice for adaptro: data[dataStart:dataEnd]
	function dataEnd(uint256 self) internal pure returns (uint256) {
		// console.log("dataEnd: %s", (self >> 0x38) & 0xffff);
		return (self >> 0x48) & 0xffff;
	}

	/// Section id
	/// @dev used for skip masking: mask | (1 << sectionId)
	function sectionId(uint256 self) internal pure returns (uint256) {
		// console.log("sectionId: %s", (self >> 0x48) & 0xff);
		return (self >> 0x58) & 0xff;
	}

	/// Section depth
	/// @dev used for partial reverting
	function sectionDepth(uint256 self) internal pure returns (uint256) {
		// console.log("sectionDepth: %s", (self >> 0x50) & 0xff);
		return (self >> 0x60) & 0xff;
	}

	/// Section end
	/// @dev used for partial reverting
	function sectionEnd(uint256 self) internal pure returns (uint256) {
		// console.log("sectionEnd: %s", (self >> 0x58) & 0xff);
		return (self >> 0x68) & 0xff;
	}

	/// Specifies if a part can transfer additional parts
	function isInput(uint256 self) internal pure returns (bool) {
		return (self >> 0x70) & 0x1 != 0x0;
	}

	/// Specifies if output token will be transferred to sender
	function isOutput(uint256 self) internal pure returns (bool) {
		return (self >> 0x78) & 0x1 != 0x0;
	}

	function getAdaptor(uint256 self, address deployer) internal view returns (address) {
		return UrbDeployer.getAddress(deployer, adaptorId(self));
	}
}
