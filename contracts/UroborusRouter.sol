// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./libraries/UrbERC20.sol";
import "./libraries/UrbDeployer.sol";
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
			address adaptor = params.deployer.getAddress(params.parts[i].adaptorId());
			uint256 idx = params.parts[i].tokenInIdx();
			address tokenIn = params.tokens[idx];
			uint256 amountIn;
			idx = params.parts[i].amountInIdx();
			if (idx < params.amounts.length) {
				amountIn = params.amounts[idx];
			} else if (i > 0) {
				amountIn = amounts[i - 1];
			} else {
				revert("UrbRouter: amount not provided");
			}
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
			if (params.parts[i].sliceDepth() > depth) {
				uint256 sliceEnd = params.parts[i].sliceEnd();
				SwapParams memory _params = SwapParams(
					params.deployer,
					params.parts[i:sliceEnd],
					params.amounts,
					params.tokens,
					params.data
				);
				try this.internalSwap(_params, skipMask, depth + 1) returns (
					uint256[] memory _amounts
				) {
					for (uint256 j; j < _amounts.length; j++) {
						amounts[i + j] = _amounts[j];
					}
				} catch {}
				i = sliceEnd;
			} else {
				address tokenIn = params.tokens[params.parts[i].tokenInIdx()];
				uint256 amountIn;
				{
					uint256 idx = params.parts[i].amountInIdx();
					if (idx < params.amounts.length) {
						amountIn = params.amounts[idx];
					} else if (i > 0) {
						amountIn = amounts[i - 1]; // what to do with this? (amounts to passed)
					} else {
						revert(); // todo revert reason
					}
				}
				bytes memory data = abi.encodeWithSelector(
					IAdaptor.swap.selector,
					tokenIn,
					amountIn,
					params.data[params.parts[i].dataStart():params.parts[i].dataEnd()]
				);
				address tokenOut = params.tokens[params.parts[i].tokenOutIdx()];
				uint256 preBalance = IERC20(tokenOut).selfBalance();
				bool success;
				(success, data) = params
					.deployer
					.getAddress(params.parts[i].adaptorId())
					.delegatecall(data);
				require(success, RevertReasonParser.parse(data));
				uint256 postBalance = IERC20(tokenOut).selfBalance();
				{
					uint256 idx = params.parts[i].amountOutMinIdx();
					if (
						idx < params.amounts.length &&
						preBalance + params.amounts[idx] < postBalance
					) {
						revert("UrbRouter: insufficient amount");
					}
				}
				i++;
			}
		}
		return amounts;
	}
}
