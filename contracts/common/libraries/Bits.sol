// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

library Bits {
	function getBits(uint value, uint pos, uint size) internal pure returns (uint) {
		return (value >> pos) & ((1 << size) - 1);
	}
}
