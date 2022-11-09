// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "hardhat/console.sol";

library UniswapV2Data {
	function checkData(bytes memory data) private pure {
		require(data.length == 26, "UniswapV2Adapter: invalid data length");
	}

	function pairAddress(bytes memory data) internal view returns (address x) {
		checkData(data);
		assembly {
			// x := shr(0x60, mload(add(data, 0x20)))
			// 0x0 + 0x20 - 12 = 20 = 0x14
			x := mload(add(data, 0x14))
		}
		console.log("pairAddress: %s", x);
	}

	function swapFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// x := and(shr(0x58, mload(add(data, 0x20))), 0xff)
			// 0x20 - 12 + 1 = 21 = 0x15
			x := and(mload(add(data, 0x15)), 0xff)
		}
		console.log("swapFee: %s", x);
	}

	function sellFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// x := and(shr(0x50, mload(add(data, 0x20))), 0xffff)
			// 0x20 - 12 + 1 + 2 = 23 = 0x17
			x := and(mload(add(data, 0x17)), 0xffff)
		}
		console.log("sellFee: %s", x);
	}

	function buyFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// x := and(shr(0x40, mload(add(data, 0x20))), 0xffff)
			// 0x20 - 12 + 1 + 2 + 2 = 25 = 0x19
			x := and(mload(add(data, 0x19)), 0xffff)
		}
		console.log("buyFee: %s", x);
	}

	function zeroForOne(bytes memory data) internal view returns (bool x) {
		checkData(data);
		assembly {
			// x := and(shr(0x30, mload(add(data, 0x20))), 0xff)
			// 0x20 - 12 + 1 + 2 + 2 + 1 = 26 = 0x1a
			x := and(mload(add(data, 0xf)), 0x1)
		}
		console.log("zeroForOne: %s", x);
	}
}
