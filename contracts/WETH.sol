// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import {IWETH} from "./interfaces/IWETH.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

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
