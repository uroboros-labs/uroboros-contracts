// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./Hex.sol";

library RevertReasonParser {
	using Hex for uint256;
	using Hex for bytes;

	enum ErrorType {
		Error,
		Panic,
		Unknown
	}

	function getType(bytes memory data) internal pure returns (ErrorType) {
		if (data.length >= 68 && data[0] == 0x08 && data[1] == 0xc3 && data[2] == 0x79 && data[3] == 0xa0)
			return ErrorType.Error;
		else if (data.length == 36 && data[0] == 0x4e && data[1] == 0x48 && data[2] == 0x7b && data[3] == 0x71)
			return ErrorType.Panic;
		else return ErrorType.Unknown;
	}

	function parse(bytes memory data) internal pure returns (string memory) {
		ErrorType errorType = getType(data);
		if (errorType == ErrorType.Error) {
			string memory reason;
			assembly {
				reason := add(data, 68)
			}
			require(data.length >= 68 + bytes(reason).length, "Invalid revert reason");
			return reason;
		} else if (errorType == ErrorType.Panic) {
			uint256 code;
			assembly {
				code := mload(add(data, 36))
			}
			return string.concat("Panic(", code.toHex(), ")");
		} else {
			return string.concat("Unknown(", data.toHex(), ")");
		}
	}
}
