// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAdaptor} from "./interfaces/IAdaptor.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Address} from "./libraries/Address.sol";

import "hardhat/console.sol";

contract RouteExecutor {
	address public immutable adaptorDeployer;

	constructor(address _adaptorDeployer) {
		adaptorDeployer = _adaptorDeployer;
	}

	struct RoutePart {
		address tokenIn;
		uint256 amountIn;
		uint256 amountOutMin;
		address receiver;
		uint256 adaptorId;
		bytes data;
	}

	function execute(RoutePart[] memory route) external payable returns (uint256[] memory) {
		uint256[] memory amounts = new uint256[](route.length);
		uint256 amountOut;
		for (uint256 i; i < route.length; i++) {
			if (route[i].amountIn > amountOut) {
				amountOut = route[i].amountIn;
				uint256 allowance = IERC20(route[i].tokenIn).allowance(msg.sender, address(this));
				require(allowance >= amountOut, "RouteExecutor: allowance not enough");
			}
			address adaptor = Address.compute(adaptorDeployer, route[i].adaptorId);
			console.log("deployer: %s, nonce: %s, adaptor: %s", adaptorDeployer, route[i].adaptorId, adaptor);
			require(adaptor.code.length != 0, "RouteExecutor: adaptor not deployed");
			amounts[i] = IAdaptor(adaptor).quote(route[i].tokenIn, amountOut, route[i].data);
			if (amounts[i] < route[i].amountOutMin) {
				for (uint256 j = i; j != ~uint256(0); j--) {
					amounts[j] = 0;
					if (route[j].amountIn != 0) {
						break;
					}
				}
			}
		}
		return amounts;
	}
}
