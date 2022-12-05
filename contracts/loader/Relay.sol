// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../common/libraries/Fee.sol";
import "./libraries/FeeERC20.sol";

/// Helper contract that transfers tokens/ETH
contract Relay {
	using SafeERC20 for IERC20;
	using FeeERC20 for IERC20;

	function transferAllGetFee(
		IERC20 token,
		address to
	) external returns (uint16 fee, uint realAmount) {
		uint amount = token.balanceOf(address(this));
		uint preBalance = token.balanceOf(to);
		token.safeTransfer(to, amount);
		uint postBalance = token.balanceOf(to);
		realAmount = postBalance - preBalance;
		fee = uint16(Fee.get(amount, realAmount));
	}
}
