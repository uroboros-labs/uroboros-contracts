// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RescueFunds is Ownable {
	using SafeERC20 for IERC20;

	function rescueToken(
		IERC20 token,
		uint256 amount,
		address to
	) external onlyOwner {
		token.safeTransfer(to, amount);
	}

	function rescueEth(uint256 amount, address payable to) external onlyOwner {
		to.transfer(amount);
	}
}
