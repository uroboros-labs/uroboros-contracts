// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAdaptor.sol";
import "./libraries/Hex.sol";
import "./libraries/UrbERC20.sol";
import "hardhat/console.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using SafeERC20 for IERC20;
	using UrbERC20 for IERC20;

	/// @param routeId hash of route's token list that are swapped
	/// @param amounts list of amounts of tokens that are swapped
	/// @notice Route payload is not stored in an event,
	/// because it can be restored by locating transaction and parsing calldata
	event RouteExecuted(bytes32 indexed routeId, uint256[] amounts);

	/// @dev used to compute adaptorAddress: keccak256(rlp([adaptorDeployer, adaptorId]))[12:]
	address public immutable adaptorDeployer;

	constructor(address _adaptorDeployer) {
		adaptorDeployer = _adaptorDeployer;
	}

	struct Part {
		uint256 amountIn;
		uint256 amountOutMin;
		uint256 sectionId;
		uint256 tokenInId;
		uint256 tokenOutId;
		address adaptor;
		bytes data;
	}

	function executeRoute(Part[] memory route, address[] memory tokens)
		external
		payable
		returns (uint256[] memory)
	{
		for (uint256 i; i < route.length; i++) {
			require(
				route[i].tokenInId < tokens.length && route[i].tokenOutId < tokens.length,
				"TOKEN_NOT_PROVIDED"
			);
		}
		uint256[] memory amounts = new uint256[](route.length);
		uint256[] memory balances = new uint256[](tokens.length);
		for (uint256 i; i < route.length; i++) {
			bool useBalance = route[i].amountIn == 0;
			amounts[i] = IAdaptor(route[i].adaptor).quote(
				tokens[route[i].tokenInId],
				useBalance ? balances[route[i].tokenInId] : route[i].amountIn,
				route[i].data
			);
			balances[route[i].tokenOutId] += amounts[i];
			if (amounts[i] < route[i].amountOutMin) {
				for (uint256 j; j < route.length; j++)
					if (route[j].sectionId == route[i].sectionId) amounts[j] = 0;
			}
			if (useBalance) {
				balances[route[i].tokenInId] = 0;
			}
		}
		return amounts;
		// bytes memory data = abi.encodeWithSelector(
		// 	this.executeRouteUnchecked.selector,
		// 	route,
		// 	tokens,
		// 	amounts
		// );
		// bool success;
		// (success, data) = address(this).delegatecall(data);
		// if (!success && msg.value != 0) {
		// 	payable(msg.sender).transfer(msg.value);
		// }
		// if (data.length % 32 != 0) {
		// 	assembly {
		// 		revert(add(0x20, data), mload(data))
		// 	}
		// }
		// return abi.decode(data, (uint256[]));
	}

	function executeRouteUnchecked(
		Part[] memory parts,
		address[] memory tokens,
		uint256[] memory amounts
	) external payable returns (uint256[] memory) {
		uint256[] memory balances = new uint256[](tokens.length);
		for (uint256 i; i < parts.length; i++) {
			if (amounts[i] == 0) {
				continue;
			}
			uint256 amountIn = parts[i].amountIn;
			IERC20 tokenIn = IERC20(tokens[parts[i].tokenInId]);
			IERC20 tokenOut = IERC20(tokens[parts[i].tokenOutId]);
			if (amountIn == 0) {
				amountIn = balances[parts[i].tokenInId];
				balances[parts[i].tokenInId] = 0;
			} else {
				if (tokenIn.isETH()) {
					require(msg.value == amountIn, "invalid msg.value");
				} else {
					console.log(
						"tokenIn: %s, balance: %s, amountIn: %s",
						address(tokenIn),
						tokenIn.balanceOf(msg.sender),
						amountIn
					);
					tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
					balances[parts[i].tokenInId] = tokenOut.balanceOf(address(this));
				}
			}
			bytes memory data = abi.encodeWithSelector(
				IAdaptor.swap.selector,
				tokenIn,
				amountIn,
				parts[i].data
			);
			bool success;
			(success, ) = parts[i].adaptor.delegatecall(data);
			balances[parts[i].tokenOutId] = tokenOut.balanceOf(address(this));
			require(
				balances[parts[i].tokenOutId] >= balances[parts[i].tokenInId],
				"balance decreased"
			);
			amounts[i] = balances[parts[i].tokenOutId] - balances[parts[i].tokenInId];
			if (!success || amounts[i] < parts[i].amountOutMin) {
				data = abi.encode(amounts);
				assembly {
					revert(add(0x20, data), mload(data))
				}
			}
		}
		return amounts;
	}
}
