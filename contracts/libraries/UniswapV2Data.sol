// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

library UniswapV2Data {
	function rev(bytes memory data) internal pure returns (bool x) {
		assembly {
			x := eq(shr(0xfe, mload(add(0x20, data))), 1)
		}
	}

	function swapFee(bytes memory data) internal pure returns (uint256 x) {
		assembly {
			x := and(shr(0xf0, mload(add(0x20, data))), 0xff)
		}
	}

	function sellFee(bytes memory data) internal pure returns (uint256 x) {
		assembly {
			x := and(shr(0xe0, mload(add(0x20, data))), 0xffff)
		}
	}

	function buyFee(bytes memory data) internal pure returns (uint256 x) {
		assembly {
			x := and(shr(0xd0, mload(add(0x20, data))), 0xffff)
		}
	}

	function pair(bytes memory data) internal pure returns (address x) {
		assembly {
			x := and(shr(0x30, mload(add(0x20, data))), 0xffffffffffffffffffffffffffffffffffffffff)
		}
	}
}
