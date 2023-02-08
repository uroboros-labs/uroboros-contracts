// SPDX-License-Identifier: No License
pragma solidity >=0.8.17;

import "./UrbDeployer.sol";
import "../../common/libraries/Bytes.sol";

library Route {
	using Bytes for bytes;
	using UrbDeployer for address;

	struct Section {
		uint id;
		uint depth;
		uint end;
	}

	struct Part {
		address tokenIn;
		address tokenOut;
		uint amountIn;
		uint amountOutMin;
		address adaptor;
		bytes adaptorData;
		Section section;
		bool isInput;
		bool isOutput;
	}

	function shift_mask(uint value, uint size) private pure returns (uint, uint) {
		return (value >> size, value & ((0x1 << size) - 0x1));
	}

	function decode(bytes calldata payload) internal pure returns (Part[] memory route) {
		uint offset;
		uint value = uint(payload.valueAt(offset));
		offset += 0x20;
		uint temp;
		(value, temp) = shift_mask(value, 0x8);
		route = new Part[](temp);
		(value, temp) = shift_mask(value, 0xa0);
		address deployer = address(uint160(temp));
		for (uint i; i < route.length; i++) {
			Part memory part = route[i];
			value = uint(payload.valueAt(offset));
			(value, temp) = shift_mask(value, 0x10);
			part.tokenIn = address(bytes20(payload.valueAt(temp)));
			(value, temp) = shift_mask(value, 0x10);
			part.tokenOut = address(bytes20(payload.valueAt(temp)));
			(value, temp) = shift_mask(value, 0x10);
			if (temp != 0x0) part.amountIn = uint(payload.valueAt(temp));
			(value, temp) = shift_mask(value, 0x10);
			if (temp != 0x0) part.amountOutMin = uint(payload.valueAt(temp));
			(value, temp) = shift_mask(value, 0x8);
			part.adaptor = deployer.getAddress(temp);
			(value, temp) = shift_mask(value, 0x10);
			uint temp2;
			(value, temp2) = shift_mask(value, 0x10);
			part.adaptorData = payload.slice(temp, temp2);
			(value, part.section.id) = shift_mask(value, 0x8);
			(value, part.section.depth) = shift_mask(value, 0x8);
			(value, part.section.end) = shift_mask(value, 0x8);
			(value, temp) = shift_mask(value, 0x8);
			part.isInput = temp != 0x0;
			(value, temp) = shift_mask(value, 0x8);
			part.isOutput = temp != 0x0;
			offset += 0x20;
		}
		return route;
	}
}
