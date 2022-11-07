// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./UrbDeployer.sol";

library Part {
	/// amountIn index
	/// @notice if part has not amountIn, returns index out of amounts[] bounds
	function amountInIdx(uint256 self) internal pure returns (uint256) {
		return self & 0xff;
	}

	/// amountOutMin index
	/// @notice if part has not amountOutMin, returns index out of amounts[] bounds
	function amountOutMinIdx(uint256 self) internal pure returns (uint256) {
		return (self >> 0x8) & 0xff;
	}

	/// tokenIn index
	/// @notice guarantied to return index in tokens[] bounds
	function tokenInIdx(uint256 self) internal pure returns (uint256) {
		return (self >> 0x10) & 0xff;
	}

	/// tokenOut index
	/// @notice guarantied to return index in tokens[] bounds
	function tokenOutIdx(uint256 self) internal pure returns (uint256) {
		return (self >> 0x18) & 0xff;
	}

	/// Adaptor id
	/// @dev used to compute adaptor address: keccak256(rlp([deployer, nonce]))
	function adaptorId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x20) & 0xff;
	}

	/// Data start
	/// @dev used to get data slice for adaptor: data[dataStart:dataEnd]
	function dataStart(uint256 self) internal pure returns (uint256) {
		return (self >> 0x28) & 0xffff;
	}

	/// Data end
	/// @dev used to get data slice for adaptro: data[dataStart:dataEnd]
	function dataEnd(uint256 self) internal pure returns (uint256) {
		return (self >> 0x30) & 0xffff;
	}

	/// Section id
	/// @dev used for skip masking: mask | (1 << sectionId)
	function sectionId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x38) & 0xff;
	}

	/// Section depth
	/// @dev used for partial reverting
	function sectionDepth(uint256 self) internal pure returns (uint256) {
		return (self >> 0x40) & 0xff;
	}

	/// Section end
	/// @dev used for partial reverting
	function sectionEnd(uint256 self) internal pure returns (uint256) {
		return (self >> 0x48) & 0xff;
	}

	function getAdaptor(uint256 self, address deployer) internal pure returns (address) {
		return UrbDeployer.getAddress(deployer, self);
	}
}
