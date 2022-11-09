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
			// 0x0 + 0x20 - 12 = 20 = 0x14
			x := mload(add(data, 0x14))
		}
		console.log("pairAddress: %s", x);
	}

	function swapFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 = 0x15
			x := and(mload(add(data, 0x15)), 0xff)
		}
		console.log("swapFee: %s", x);
	}

	function sellFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 = 0x17
			x := and(mload(add(data, 0x17)), 0xffff)
		}
		console.log("sellFee: %s", x);
	}

	function buyFee(bytes memory data) internal view returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 + 0x2 = 0x19
			x := and(mload(add(data, 0x19)), 0xffff)
		}
		console.log("buyFee: %s", x);
	}

	function zeroForOne(bytes memory data) internal view returns (bool x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 + 0x2 + 0x1 = 0x1a
			x := and(mload(add(data, 0x1a)), 0x1)
		}
		console.log("zeroForOne: %s", x);
	}
}
