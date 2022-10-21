// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

// import "hardhat/console.sol";
// import "./Hex.sol";

library UniswapV2Data {
	function rev(bytes memory data) internal pure returns (bool x) {
		// bytes32 _data;
		// assembly {
		// 	_data := shr(0xf8, mload(add(0x20, data)))
		// }
		// console.log("_data: %s", Hex.toHex(uint256(_data)));
		assembly {
			x := eq(shr(0xf8, mload(add(0x20, data))), 1)
		}
		// console.log("rev: %s", x);
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
