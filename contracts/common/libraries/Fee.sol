// SPDX-License-Identifier: MIT
pragma solidity >=0.8.14;

library Fee {
	uint256 internal constant MAX = 1e4;

	function get(uint256 amountOriginal, uint256 amountLessFee) internal pure returns (uint256) {
		require(amountOriginal > 0, "Fee: amount should be nonzero");
		return MAX - (amountLessFee * MAX) / amountOriginal;
	}

	// ajacent fee, returns nonzero value
	function adj(uint256 fee) internal pure returns (uint256) {
		require(fee < MAX, "Fee: fee should be less than MAX");
		return MAX - fee;
	}

	function getAmountOriginal(uint256 fee, uint256 amountLessFee) internal pure returns (uint256) {
		return (amountLessFee * MAX) / adj(fee);
	}

	function getAmountLessFee(uint256 fee, uint256 amountOriginal) internal pure returns (uint256) {
		return (amountOriginal * adj(fee)) / MAX;
	}

	function feeMul(uint256 fee1, uint256 fee2) internal pure returns (uint256) {
		return (MAX * (fee1 + fee2) - fee1 * fee2) / MAX + 1;
	}
}
