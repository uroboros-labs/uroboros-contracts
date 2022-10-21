// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAdaptor} from "./interfaces/IAdaptor.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Address} from "./libraries/Address.sol";
import {RevertReasonParser} from "./libraries/RevertReasonParser.sol";

import "hardhat/console.sol";

contract RouteExecutor {
	// Route is not included into event, to save gas - it can be later lookuped
	event RouteExecuted(bytes32 indexed routeId, uint256[] amounts);

	address public immutable adaptorDeployer;

	constructor(address _adaptorDeployer) {
		adaptorDeployer = _adaptorDeployer;
	}

	struct RoutePart {
		address tokenIn;
		uint256 amountIn;
		uint256 amountOutMin;
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
			require(adaptor.code.length != 0, "RouteExecutor: adaptor not deployed");
			amountOut = amounts[i] = IAdaptor(adaptor).quote(
				route[i].tokenIn,
				amountOut,
				route[i].data
			);
			if (amounts[i] < route[i].amountOutMin) {
				for (uint256 j = i; j != ~uint256(0); j--) {
					// zeroed amounts are skipped
					amounts[j] = 0;
					if (route[j].amountIn != 0) {
						break;
					}
				}
			}
		}
		amountOut = 0;
		for (uint256 i; i < route.length; i++) {
			if (amounts[i] == 0) continue;
			// check balance somewhere here
			if (route[i].amountIn > amountOut) {
				amountOut = route[i].amountIn;
				IERC20(route[i].tokenIn).transferFrom(msg.sender, address(this), amountOut);
			}
			address adaptor = Address.compute(adaptorDeployer, route[i].adaptorId);
			bytes memory data = abi.encodeWithSelector(
				IAdaptor.swap.selector,
				route[i].tokenIn,
				amountOut,
				route[i].data
			);
			bool success;
			(success, data) = adaptor.delegatecall(data);
			require(
				success,
				string.concat(
					"RouteExecutor: adaptor failed to swap: ",
					RevertReasonParser.parse(data)
				)
			);
		}
		emit RouteExecuted(_getRouteId(route), amounts);
		return amounts;
	}

	function _getRouteId(RoutePart[] memory route) internal pure returns (bytes32) {
		for (uint256 i; i < route.length; i++) {
			route[i].amountIn = 0;
			route[i].amountOutMin = 0;
		}
		return keccak256(abi.encode(route));
	}
}
