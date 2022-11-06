// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./Hex.sol";

library RevertReasonParser {
	using Hex for uint256;
	using Hex for bytes;

	function parse(bytes memory data) internal pure returns (string memory) {
		if (
			data.length >= 68 &&
			data[0] == 0x08 &&
			data[1] == 0xc3 &&
			data[2] == 0x79 &&
			data[3] == 0xa0
		) {
			string memory reason;
			assembly {
				reason := add(data, 68)
			}
			require(data.length >= 68 + bytes(reason).length, "Invalid revert reason");
			return string.concat("Error(", reason, ")");
		} else if (
			data.length == 36 &&
			data[0] == 0x4e &&
			data[1] == 0x48 &&
			data[2] == 0x7b &&
			data[3] == 0x71
		) {
			uint256 code;
			assembly {
				code := mload(add(data, 36))
			}
			return string.concat("Panic(", code.toHex(), ")");
		}
		return string.concat("Unknown(", data.toHex(), ")");
	}
}
