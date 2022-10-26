// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAdaptor.sol";
import "./libraries/Hex.sol";
import "./libraries/Math.sol";
import "./libraries/SafeMath.sol";
import "./libraries/UrbERC20.sol";
import "hardhat/console.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using SafeERC20 for IERC20;
	using UrbERC20 for IERC20;
	using Math for uint256;
	using SafeMath for uint256;

	/// @param routeId hash of route's token list that are swapped
	/// @param amounts list of amounts of tokens that are swapped
	/// @notice Route payload is not included to event,
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
		// checkRoute(route, tokens);
		uint256[] memory amounts = new uint256[](route.length);
		uint256[] memory balances = new uint256[](tokens.length);
		// todo skip
		for (uint256 i; i < route.length; ) {
			bool useBalance = route[i].amountIn.isZero();
			amounts[i] = IAdaptor(route[i].adaptor).quote(
				tokens[route[i].tokenInId],
				useBalance ? balances[route[i].tokenInId] : route[i].amountIn,
				route[i].data
			);
			if (amounts[i] < route[i].amountOutMin) {
				uint256 sectionId = route[i].sectionId;
				for (i = 0; i < route.length; i++) {
					if (route[i].sectionId != sectionId) break;
					amounts[i] = 0;
				}
				continue;
			}
			balances[route[i].tokenOutId] += amounts[i];
			if (useBalance) {
				balances[route[i].tokenInId] = 0;
			}
			i++;
		}
		bytes memory data = abi.encodeWithSelector(this._executeSection.selector, route, tokens);
		bool success;
		(success, data) = address(this).delegatecall(data);
		return amounts;
	}

	/// Recursively executes nested sections, returns amounts
	/// @notice for internal use purposes only
	/// @dev should be called from 'executeRoute' function or from itself
	function _executeSection(Part[] memory section, address[] memory tokens)
		external
		returns (uint256[] memory)
	{
		uint256 sectionId = section[0].sectionId;
		uint256[] memory amounts = new uint256[](section.length);
		for (uint256 i; i < section.length; ) {
			if (section[i].sectionId != sectionId) {
				// steps to the end of the section
				i = _executeNextSection(section, tokens, amounts, i);
			} else {
				_swapPart(section, tokens, amounts, i);
				i++;
			}
		}
		return amounts;
	}

	function _swapPart(
		Part[] memory section,
		address[] memory tokens,
		uint256[] memory amounts,
		uint256 i
	) internal {
		uint256 amountIn = section[i].amountIn;
		address tokenIn = tokens[section[i].tokenInId];
		address tokenOut = tokens[section[i].tokenOutId];
		// if parts' amountIn not specified, use all avail. balance
		// else if amountIn is greater than avail., transfer difference
		if (amountIn.isZero()) {
			amountIn = IERC20(tokenIn).selfBalance();
		}
		bytes memory data = abi.encodeWithSelector(
			IAdaptor.swap.selector,
			tokenIn,
			amountIn,
			section[i].data
		);
		bool ok;
		uint256 preBalance = IERC20(tokenOut).selfBalance();
		(ok, ) = section[i].adaptor.delegatecall(data);
		require(ok);
		uint256 postBalance = IERC20(tokenOut).selfBalance();
		amounts[i] = postBalance.sub(preBalance);
		if (amounts[i] < section[i].amountOutMin) {
			assembly {
				revert(add(0x20, amounts), mload(amounts))
			}
		}
	}

	function _executeNextSection(
		Part[] memory section,
		address[] memory tokens,
		uint256[] memory amounts,
		uint256 i
	) internal returns (uint256) {
		Part[] memory nextSection = _getNextSection(section, i);
		bytes memory data = abi.encodeWithSelector(
			this._executeSection.selector,
			nextSection,
			tokens
		);
		bool success;
		(success, data) = address(this).delegatecall(data);
		uint256[] memory nextAmounts = abi.decode(data, (uint256[]));
		uint256 j;
		for (; j < nextAmounts.length; j++) amounts[i + j] = nextAmounts[j];
		return i + j;
	}

	/// @param section currently executed section
	/// @param i current part index
	/// @return nextSection next section
	/// @notice called when current parts' sectionId not equals to previos.
	function _getNextSection(Part[] memory section, uint256 i)
		internal
		pure
		returns (Part[] memory)
	{
		uint256 j;
		for (; j < section.length; j++) if (section[j].sectionId != section[i].sectionId) break;
		uint256 nextLength = j - i;
		Part[] memory nextSection = new Part[](nextLength);
		for (j = 0; j < nextLength; j++) nextSection[j] = section[i + j];
		return nextSection;
	}
}
