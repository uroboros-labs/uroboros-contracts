// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAdaptor} from "./interfaces/IAdaptor.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Address} from "./libraries/Address.sol";
import {RevertReasonParser} from "./libraries/RevertReasonParser.sol";

import "hardhat/console.sol";

contract UroborusRouter {
	uint256 constant WRAP_ETH = 1;
	uint256 constant UNWRAP_ETH = 2;
	uint256 constant MINT = 4;

	// Route is not included into event, to save gas - it can be later lookuped
	event RouteExecuted(bytes32 indexed routeId, uint256[] amounts);

	address public immutable adaptorDeployer;

	constructor(address _adaptorDeployer) {
		adaptorDeployer = _adaptorDeployer;
	}

	struct Part {
		uint256 amountIn; // 32;
		uint256 amountOutMin; // 32;
		uint256 tokenInId; // 1
		uint256 tokenOutId; // 1; tokens length can be inferred by max of those two
		uint256 adaptorId; // 2;
		bytes data; // 2; can use dataPtr and dataSize
		// uint dataSize; // 2
	}

	// Encoding:
	// 	number of parts
	// 	parts
	// 	tokens
	// 	data

	// can have balances for each token

	function executeRoute(Part[] calldata parts, address[] calldata tokens)
		external
		payable
		returns (uint256[] memory)
	{
		uint256[] memory amounts = new uint256[](parts.length);
		uint256 amountOut;
		for (uint256 i; i < parts.length; i++) {
			address tokenIn = tokens[parts[i].tokenInId];
			if (parts[i].amountIn > amountOut) {
				amountOut = parts[i].amountIn;
				uint256 allowance = IERC20(tokenIn).allowance(msg.sender, address(this));
				require(allowance >= amountOut, "RouteExecutor: allowance not enough");
			}
			address adaptor = Address.compute(adaptorDeployer, parts[i].adaptorId);
			require(adaptor.code.length != 0, "RouteExecutor: adaptor not deployed");
			amountOut = amounts[i] = IAdaptor(adaptor).quote(tokenIn, amountOut, parts[i].data);
			if (amounts[i] < parts[i].amountOutMin) {
				for (uint256 j = i; j != ~uint256(0); j--) {
					// zeroed amounts are skipped
					amounts[j] = 0;
					if (parts[j].amountIn != 0) {
						break;
					}
				}
			}
		}
		amountOut = 0;
		for (uint256 i; i < parts.length; i++) {
			address tokenIn = tokens[parts[i].tokenInId];
			if (amounts[i] == 0) continue;
			// check balance somewhere here
			if (parts[i].amountIn > amountOut) {
				amountOut = parts[i].amountIn;
				IERC20(tokenIn).transferFrom(msg.sender, address(this), amountOut);
			}
			address adaptor = Address.compute(adaptorDeployer, parts[i].adaptorId);
			bytes memory data = abi.encodeWithSelector(
				IAdaptor.swap.selector,
				parts[i].tokenInId,
				amountOut,
				parts[i].data
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
		// bytes32 routeId = getRouteId(parts, tokens, amounts);
		// emit RouteExecuted(routeId, amounts);
		return amounts;
	}

	function getRouteId(
		Part[] memory parts,
		address[] memory tokens,
		uint256[] memory amounts
	) internal pure returns (bytes32 _routeId) {
		uint256 ptr1;
		assembly {
			ptr1 := mload(0x40)
		}
		uint256 ptr2 = ptr1;
		for (uint256 i; i < parts.length; i++) {
			if (amounts[i] != 0) {
				address tokenIn = tokens[parts[i].tokenInId];
				assembly {
					mstore(ptr2, tokenIn)
				}
				ptr2 += 0x14;
			}
		}
		assembly {
			_routeId := keccak256(ptr1, sub(ptr2, ptr1))
		}
		for (; ptr1 <= ptr2; ptr1 += 0x20) {
			assembly {
				mstore(ptr1, 0x0)
			}
		}
	}
}
