// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import '@openzeppelin/contracts/utils/Strings.sol';

library Strings2 {
	using Strings for *;

	function toString(uint[][] memory self) internal pure returns (string memory s) {
		s = '[';
		uint maxNumberLength = getNumberLength(findMaxNumber(self));
		for (uint i; i < self.length; i++) {
			for (uint j; j < self[i].length; j++) {
				string memory v = self[i][j].toString();
				v = padUpToWithSpaces(v, maxNumberLength);
				if (j == 0) {
					if (i == 0) {
						s = string.concat(s, '[', v, ', ');
					} else {
						s = string.concat(s, ' [', v, ', ');
					}
				} else if (j < self[i].length - 1) {
					s = string.concat(s, v, ', ');
				} else if (i < self.length - 1) {
					s = string.concat(s, v, ']\n');
				} else {
					s = string.concat(s, v, ']]');
				}
			}
		}
	}

	function findMaxNumber(uint[][] memory arr) private pure returns (uint max) {
		for (uint i; i < arr.length; i++) {
			for (uint j; j < arr[i].length; j++) {
				uint num = arr[i][j];
				if (num > max) max = num;
			}
		}
	}

	function getNumberLength(uint number) private pure returns (uint length) {
		length = 1;
		while (number != 0) {
			number /= 10;
			length++;
		}
	}

	function padUpToWithSpaces(
		string memory str,
		uint length
	) private pure returns (string memory) {
		while (bytes(str).length < length) {
			str = string.concat(str, ' ');
		}
		return str;
	}
}
