// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library UniswapV2Data {
	function checkData(bytes memory data) private pure {
		require(data.length == 26, "UniswapV2Adapter: invalid data length");
	}

	function pairAddress(bytes memory data) internal pure returns (address x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 12 = 20 = 0x14
			x := mload(add(data, 0x14))
		}
	}

	function swapFee(bytes memory data) internal pure returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 = 0x15
			x := and(mload(add(data, 0x15)), 0xff)
		}
	}

	function sellFee(bytes memory data) internal pure returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 = 0x17
			x := and(mload(add(data, 0x17)), 0xffff)
		}
	}

	function buyFee(bytes memory data) internal pure returns (uint256 x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 + 0x2 = 0x19
			x := and(mload(add(data, 0x19)), 0xffff)
		}
	}

	function zeroForOne(bytes memory data) internal pure returns (bool x) {
		checkData(data);
		assembly {
			// 0x0 + 0x20 - 0xc + 0x1 + 0x2 + 0x2 + 0x1 = 0x1a
			x := and(mload(add(data, 0x1a)), 0x1)
		}
	}
}
