// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/utils/Strings.sol";

library Strings2 {
	using Strings for uint256;

	function toString(uint256[] memory self) internal pure returns (string memory s) {
		s = "[";
		for (uint256 i; i < self.length; i++) {
			if (i == self.length - 0x1) s = string.concat(s, self[i].toString());
			else s = string.concat(s, self[i].toString(), ", ");
		}
		s = string.concat(s, "]");
	}

	function toString(uint256[][] memory self) internal pure returns (string memory s) {
		s = "[";
		for (uint256 i; i < self.length; i++) {
			if (i == self.length - 0x1) s = string.concat(s, toString(self[i]));
			else s = string.concat(s, toString(self[i]), ", ");
		}
		s = string.concat(s, "]");
	}
}
