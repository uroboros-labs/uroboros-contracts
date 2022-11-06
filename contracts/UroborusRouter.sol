// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
		returns (uint256[] memory, uint256)
	{
		(uint256[] memory amounts, uint256 skip) = simulateRoute(route, tokens);
		_callExecuteSection(route, tokens, skip, 0);
		return (amounts, skip);
	}

	function simulateRoute(Part[] memory route, address[] memory tokens)
		internal
		view
		returns (uint256[] memory, uint256)
	{
		uint256[] memory amounts = new uint256[](route.length);
		uint256 skip;
		for (uint256 i; i < route.length; i++) {
			if (skip & (1 << route[i].sectionId) != 0) continue;
			uint256 amountIn = route[i].amountIn;
			if (amountIn == 0)
				for (uint256 j; j < i; j++) {
					if (skip & (1 << route[j].sectionId) != 0) continue;
					if (route[j].tokenOutId == route[i].tokenInId) amountIn += amounts[j];
					else if (route[j].tokenInId == route[i].tokenInId) {
						if (route[j].amountIn == 0) amountIn -= amounts[j - 1];
						else amountIn -= route[j].amountIn;
					}
				}
			amounts[i] = IAdaptor(route[i].adaptor).quote(
				tokens[route[i].tokenInId],
				amountIn,
				route[i].data
			);
			if (amounts[i] < route[i].amountOutMin) skip |= (1 << route[i].sectionId);
		}
		return (amounts, skip);
	}

	function _callExecuteSection(
		Part[] memory section,
		address[] memory tokens,
		uint256 skip,
		uint256 sectionId
	) internal returns (uint256[] memory) {
		bytes memory data = abi.encodeWithSelector(
			this._executeSection.selector,
			section,
			tokens,
			skip,
			sectionId
		);
		(, data) = address(this).delegatecall(data);
		return abi.decode(data, (uint256[]));
	}

	function _executeSection(
		Part[] memory section,
		address[] memory tokens,
		uint256 skip,
		uint256 sectionId
	) external returns (uint256[] memory) {
		uint256[] memory amounts = new uint256[](section.length);
		for (uint256 i; i < section.length; ) {
			if (section[i].sectionId > sectionId) {
				uint256 j;
				for (; j < section.length; j++) if (section[j].sectionId <= sectionId) break;
				uint256 nextLength = j - i;
				Part[] memory nextSection = new Part[](nextLength);
				for (uint256 k; k < nextLength; k++) nextSection[k] = section[i + k];
				uint256[] memory nextAmounts = this._executeSection(
					nextSection,
					tokens,
					skip,
					section[i].sectionId
				);
				for (uint256 k; k < nextLength; k++) amounts[i + k] = nextAmounts[k];
				i += nextLength;
			} else {
				i++;
			}
		}
		return amounts;
	}
}
