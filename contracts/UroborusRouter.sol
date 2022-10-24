// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAdaptor.sol";
import "./libraries/Hex.sol";
import "hardhat/console.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using SafeERC20 for IERC20;

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
		uint256 tokenInId;
		uint256 tokenOutId;
		// uint256 adaptorId;
		address adapter;
		bytes data;
	}

	function executeRoute(Part[] memory parts, address[] memory tokens)
		external
		payable
		returns (uint256[] memory)
	{
		for (uint256 i; i < parts.length; i++) {
			require(
				parts[i].tokenInId < tokens.length && parts[i].tokenOutId < tokens.length,
				"token not provided"
			);
		}
		uint256[] memory amounts = new uint256[](parts.length);
		// balance is used when no amountIn specified
		// could use balanceOf, but this is more efficient
		uint256[] memory balances = new uint256[](tokens.length);
		for (uint256 i; i < parts.length; i++) {
			uint256 amountIn = parts[i].amountIn;
			if (amountIn == 0) {
				amountIn = balances[parts[i].tokenInId];
				balances[parts[i].tokenInId] = 0;
			}
			amounts[i] = IAdaptor(parts[i].adapter).quote(
				tokens[parts[i].tokenInId],
				amountIn,
				parts[i].data
			);
			balances[parts[i].tokenOutId] += amounts[i];
			if (amounts[i] < parts[i].amountOutMin) {
				for (uint256 j = i; j != type(uint256).max; j--) {
					amounts[j] = 0;
					if (parts[j].amountIn != 0 || parts[j].tokenInId == parts[i].tokenOutId) {
						break;
					}
				}
			}
		}
		bytes memory data = abi.encodeWithSelector(
			this.executeRouteUnchecked.selector,
			parts,
			tokens,
			amounts
		);
		bool success;
		(success, data) = address(this).delegatecall(data);
		if (!success && msg.value != 0) {
			payable(msg.sender).transfer(msg.value);
		}
		if (data.length % 32 != 0) {
			assembly {
				revert(add(0x20, data), mload(data))
			}
		}
		return abi.decode(data, (uint256[]));
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
			address tokenIn = tokens[parts[i].tokenInId];
			address tokenOut = tokens[parts[i].tokenOutId];
			if (amountIn == 0) {
				amountIn = balances[parts[i].tokenInId];
				balances[parts[i].tokenInId] = 0;
			} else {
				if (tokenIn == address(0)) {
					require(msg.value == amountIn, "invalid msg.value");
				} else {
					console.log(
						"tokenIn: %s, balance: %s, amountIn: %s",
						tokenIn,
						IERC20(tokenIn).balanceOf(msg.sender),
						amountIn
					);
					IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
					balances[parts[i].tokenInId] = IERC20(tokenOut).balanceOf(address(this));
				}
			}
			bytes memory data = abi.encodeWithSelector(
				IAdaptor.swap.selector,
				tokenIn,
				amountIn,
				parts[i].data
			);
			bool success;
			(success, ) = parts[i].adapter.delegatecall(data);
			balances[parts[i].tokenOutId] = IERC20(tokenOut).balanceOf(address(this));
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
