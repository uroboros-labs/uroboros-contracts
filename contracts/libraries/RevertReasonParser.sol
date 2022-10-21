// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import {Hex} from "./Hex.sol";

library RevertReasonParser {
	using Hex for uint256;
	using Hex for bytes;

	function parse(bytes memory data) internal pure returns (string memory) {
		if (
			data.length >= 68 &&
			data[0] == "\x08" &&
			data[1] == "\xc3" &&
			data[2] == "\x79" &&
			data[3] == "\xa0"
		) {
			string memory reason;
			assembly {
				reason := add(data, 68)
			}
			require(data.length >= 68 + bytes(reason).length, "Invalid revert reason");
			return string.concat("Error(", reason, ")");
		} else if (
			data.length == 36 &&
			data[0] == "\x4e" &&
			data[1] == "\x48" &&
			data[2] == "\x7b" &&
			data[3] == "\x71"
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
