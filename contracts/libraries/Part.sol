// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

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

	function tokenInIdx(uint256 self) internal pure returns (uint256) {
		return (self >> 0x10) & 0xff;
	}

	function tokenOutIdx(uint256 self) internal pure returns (uint256) {
		return (self >> 0x18) & 0xff;
	}

	function adaptorId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x20) & 0xff;
	}

	function dataStart(uint256 self) internal pure returns (uint256) {
		return (self >> 0x28) & 0xffff;
	}

	function dataEnd(uint256 self) internal pure returns (uint256) {
		return (self >> 0x30) & 0xffff;
	}

	function sectionId(uint256 self) internal pure returns (uint256) {
		return (self >> 0x38) & 0xff;
	}

	function sliceDepth(uint256 self) internal pure returns (uint256) {
		return (self >> 0x40) & 0xff;
	}

	function sliceEnd(uint256 self) internal pure returns (uint256) {
		return (self >> 0x48) & 0xff;
	}
}
