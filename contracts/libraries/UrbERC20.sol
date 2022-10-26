// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UrbERC20 {
	using SafeERC20 for IERC20;

	IERC20 private constant _ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
	IERC20 private constant _ZERO_ADDRESS = IERC20(0x0000000000000000000000000000000000000000);

	function isETH(IERC20 token) internal pure returns (bool) {
		return (token == _ZERO_ADDRESS || token == _ETH_ADDRESS);
	}

	function transfer(
		IERC20 token,
		address to,
		uint256 amount
	) internal {
		if (isETH(token)) {
			(bool ok, ) = to.call{value: amount}("");
			require(ok, "UrbERC20: ETH_TRANSFER_FAILED");
		} else {
			token.safeTransfer(to, amount);
		}
	}

	function selfBalance(IERC20 token) internal view returns (uint256) {
		return token.balanceOf(address(this));
	}
}
