// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./UrbDeployer.sol";

library Part {
	/// amountIn index
	/// @notice if part has not amountIn, returns index out of amounts[] bounds
	function amountInIdx(uint256 self) internal view returns (uint256) {
		console.log("amountInIdx: %s", self & 0xff);
		return self & 0xff;
	}

	/// amountOutMin index
	/// @notice if part has not amountOutMin, returns index out of amounts[] bounds
	function amountOutMinIdx(uint256 self) internal view returns (uint256) {
		console.log("amountOutMinIdx: %s", self & (self >> 0x8) & 0xff);
		return (self >> 0x8) & 0xff;
	}

	/// tokenIn index
	/// @notice guarantied to return index in tokens[] bounds
	function tokenInIdx(uint256 self) internal view returns (uint256) {
		console.log("tokenInIdx: %s", (self >> 0x10) & 0xff);
		return (self >> 0x10) & 0xff;
	}

	/// tokenOut index
	/// @notice guarantied to return index in tokens[] bounds
	function tokenOutIdx(uint256 self) internal view returns (uint256) {
		console.log("tokenOutIdx: %s", (self >> 0x18) & 0xff);
		return (self >> 0x18) & 0xff;
	}

	/// Adaptor id
	/// @dev used to compute adaptor address: keccak256(rlp([deployer, nonce]))
	function adaptorId(uint256 self) internal view returns (uint256) {
		console.log("adaptorId: %s", (self >> 0x20) & 0xff);
		return (self >> 0x20) & 0xff;
	}

	/// Data start
	/// @dev used to get data slice for adaptor: data[dataStart:dataEnd]
	function dataStart(uint256 self) internal view returns (uint256) {
		console.log("dataStart: %s", (self >> 0x28) & 0xffff);
		return (self >> 0x28) & 0xffff;
	}

	/// Data end
	/// @dev used to get data slice for adaptro: data[dataStart:dataEnd]
	function dataEnd(uint256 self) internal view returns (uint256) {
		console.log("dataEnd: %s", (self >> 0x38) & 0xffff);
		return (self >> 0x38) & 0xffff;
	}

	/// Section id
	/// @dev used for skip masking: mask | (1 << sectionId)
	function sectionId(uint256 self) internal view returns (uint256) {
		console.log("sectionId: %s", (self >> 0x48) & 0xff);
		return (self >> 0x48) & 0xff;
	}

	/// Section depth
	/// @dev used for partial reverting
	function sectionDepth(uint256 self) internal view returns (uint256) {
		console.log("sectionDepth: %s", (self >> 0x50) & 0xff);
		return (self >> 0x50) & 0xff;
	}

	/// Section end
	/// @dev used for partial reverting
	function sectionEnd(uint256 self) internal view returns (uint256) {
		console.log("sectionEnd: %s", (self >> 0x58) & 0xff);
		return (self >> 0x58) & 0xff;
	}

	function getAdaptor(uint256 self, address deployer) internal view returns (address) {
		return UrbDeployer.getAddress(deployer, adaptorId(self));
	}
}
