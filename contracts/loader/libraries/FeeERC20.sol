// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../common/libraries/Fee.sol";

library FeeERC20 {
	using SafeERC20 for IERC20;

	function transferGetFee(IERC20 token, address to, uint amount) internal returns (uint16) {
		uint preBalance = token.balanceOf(to);
		token.safeTransfer(to, amount);
		uint postBalance = token.balanceOf(to);
		return uint16(Fee.get(amount, postBalance - preBalance));
	}
}
