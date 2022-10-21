// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library Hex {
	function toHex(uint256 value) internal pure returns (string memory) {
		return toHex(abi.encodePacked(value));
	}

	function toHex(bytes memory data) internal pure returns (string memory) {
		bytes16 alphabet = 0x30313233343536373839616263646566;
		bytes memory str = new bytes(2 + data.length * 2);
		str[0] = "0";
		str[1] = "x";
		for (uint256 i = 0; i < data.length; i++) {
			str[2 * i + 2] = alphabet[uint8(data[i] >> 4)];
			str[2 * i + 3] = alphabet[uint8(data[i] & 0x0f)];
		}
		return string(str);
	}
}
