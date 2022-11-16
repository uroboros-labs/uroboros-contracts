// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IWETH.sol";

contract WETH is ERC20, IWETH {
	constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

	function deposit() external payable {
		_mint(_msgSender(), msg.value);
	}

	function withdraw(uint256 amount) external {
		_burn(_msgSender(), amount);
		Address.sendValue(payable(_msgSender()), amount);
	}
}
