// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./libraries/UrbERC20.sol";
import "./libraries/RevertReasonParser.sol";
import "./libraries/Part.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using Part for uint256;
	using UrbDeployer for address;
	using UrbERC20 for IERC20;

	struct SwapParams {
		address deployer;
		uint256[] parts;
		uint256[] amounts;
		address[] tokens;
		bytes data;
	}

	function swap(SwapParams calldata params) external payable returns (uint256[] memory amounts) {
		amounts = new uint256[](params.parts.length);
		uint256 skipMask;
		for (uint256 i; i < params.parts.length; i++) {
			if (skipMask & (1 << params.parts[i].sectionId()) != 0) {
				continue;
			}
			address adaptor = params.parts[i].getAdaptor(params.deployer);
			uint256 idx = params.parts[i].tokenInIdx();
			address tokenIn = params.tokens[idx];
			uint256 amountIn = getAmountIn(params, amounts, i);
			bytes memory data = params.data[params.parts[i].dataStart():params.parts[i].dataEnd()];
			amounts[i] = IAdaptor(adaptor).quote(tokenIn, amountIn, data);
			idx = params.parts[i].amountOutMinIdx();
			if (idx < params.amounts.length && amounts[i] < params.amounts[idx]) {
				skipMask |= 1 << params.parts[i].sectionId();
			}
		}
		this.internalSwap(params, skipMask, 0);
	}

	function internalSwap(
		SwapParams calldata params,
		uint256 skipMask,
		uint256 depth
	) external returns (uint256[] memory) {
		uint256[] memory amounts = new uint256[](params.parts.length);
		for (uint256 i; i < params.parts.length; ) {
			if (skipMask & (1 << params.parts[i].sectionId()) != 0) {
				continue;
			}
			if (params.parts[i].sectionDepth() > depth) {
				uint256 sectionEnd = params.parts[i].sectionEnd();
				SwapParams memory sectionParams = SwapParams(
					params.deployer,
					params.parts[i:sectionEnd],
					params.amounts,
					params.tokens,
					params.data
				);
				try this.internalSwap(sectionParams, skipMask, depth + 1) returns (
					uint256[] memory sectionAmounts
				) {
					for (uint256 j; j < sectionAmounts.length; j++) {
						amounts[i + j] = sectionAmounts[j];
					}
				} catch {}
				i = sectionEnd;
			} else {
				address tokenIn = params.tokens[params.parts[i].tokenInIdx()];
				uint256 amountIn = getAmountIn(params, amounts, i);
				bytes memory data = abi.encodeWithSelector(
					IAdaptor.swap.selector,
					tokenIn,
					amountIn,
					params.data[params.parts[i].dataStart():params.parts[i].dataEnd()]
				);
				address tokenOut = params.tokens[params.parts[i].tokenOutIdx()];
				uint256 preBalance = IERC20(tokenOut).selfBalance();
				bool success;
				(success, data) = params.parts[i].getAdaptor(params.deployer).delegatecall(data);
				require(success, RevertReasonParser.parse(data));
				uint256 postBalance = IERC20(tokenOut).selfBalance();
				uint256 idx = params.parts[i].amountOutMinIdx();
				require(
					idx > params.amounts.length || preBalance + params.amounts[idx] >= postBalance,
					"UrbRouter: insufficient amount"
				);
				i++;
			}
		}
		return amounts;
	}

	function getAmountIn(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 partIdx
	) internal pure returns (uint256) {
		uint256 idx = params.parts[partIdx].amountInIdx();
		if (idx <= params.amounts.length) {
			return params.amounts[idx];
		} else if (partIdx > 0) {
			return amounts[partIdx - 1];
		} else {
			revert("UrbRouter: amount not provided");
		}
	}
}
