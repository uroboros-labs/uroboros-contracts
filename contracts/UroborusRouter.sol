// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./libraries/UrbERC20.sol";
import "./libraries/RevertReasonParser.sol";
import "./libraries/Part.sol";
import "./libraries/Bitmap.sol";

import "hardhat/console.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using Part for uint256;
	using UrbDeployer for address;
	using UrbERC20 for IERC20;
	using BitMap for uint256;

	event Error(string reason);

	struct SwapParams {
		address deployer;
		uint256[] parts;
		uint256[] amounts;
		address[] tokens;
		bytes data;
	}

	function swap(SwapParams calldata params)
		external
		payable
		returns (uint256[] memory amounts, uint256 skipMask)
	{
		(amounts, skipMask) = simulateSwap(params);
		bytes memory data = abi.encodeWithSelector(
			this.swapSection.selector,
			params,
			amounts,
			skipMask,
			0x0,
			params.parts.length,
			0x0
		);
		bool success;
		(success, data) = address(this).delegatecall(data);
		require(success, RevertReasonParser.parse(data));
	}

	function simulateSwap(SwapParams calldata params)
		internal
		view
		returns (uint256[] memory amounts, uint256 skipMask)
	{
		amounts = new uint256[](params.parts.length);
		for (uint256 i; i < params.parts.length; ) {
			if (skipMask.get(params.parts[i].sectionId())) {
				i++;
				continue;
			}
			address adaptor = params.parts[i].getAdaptor(params.deployer);
			address tokenIn = params.tokens[params.parts[i].tokenInIdx()];
			uint256 amountIn = getAmountIn(params, amounts, i);
			console.log("quote:: i: %s, amountIn: %s", i, amountIn);
			bytes memory data = params.data[params.parts[i].dataStart():params.parts[i].dataEnd()];
			amounts[i] = IAdaptor(adaptor).quote(tokenIn, amountIn, data);
			if (!checkAmountOutMin(params, amounts, i)) {
				skipMask = skipMask.set(params.parts[i].sectionId());
				i = params.parts[i].sectionEnd();
			} else {
				i++;
			}
		}
	}

	function swapSection(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 skipMask,
		uint256 start,
		uint256 end,
		uint256 depth
	) external returns (uint256[] memory) {
		console.log("section:: start: %s, end: %s, depth: %s", start, end, depth);
		for (uint256 i = start; i < end; ) {
			if (skipMask.get(params.parts[i].sectionId())) {
				i++;
				continue;
			}
			if (params.parts[i].sectionDepth() > depth) {
				uint256 sectionEnd = params.parts[i].sectionEnd();
				bytes memory data = abi.encodeWithSelector(
					this.swapSection.selector,
					params,
					amounts,
					skipMask,
					i,
					sectionEnd,
					depth + 0x1
				);
				bool success;
				(success, data) = address(this).delegatecall(data);
				if (success) {
					amounts = abi.decode(data, (uint256[]));
				} else {
					emit Error(RevertReasonParser.parse(data));
				}
				i = sectionEnd;
			} else {
				swapPart(params, amounts, i++);
			}
		}
		return amounts;
	}

	function swapPart(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 partIdx
	) internal {
		console.log("swap:: i: %s, sectionId: %s", partIdx, params.parts[partIdx].sectionId());
		address tokenIn = params.tokens[params.parts[partIdx].tokenInIdx()];
		uint256 amountIn = getAmountIn(params, amounts, partIdx);
		console.log("swap:: amountIn: %s", amountIn);
		{
			// todo this
			uint256 balance = IERC20(tokenIn).selfBalance();
			if (balance < amountIn) {
				unchecked {
					IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn - balance);
				}
			}
		}
		bytes memory data = abi.encodeWithSelector(
			IAdaptor.swap.selector,
			tokenIn,
			amountIn,
			params.data[params.parts[partIdx].dataStart():params.parts[partIdx].dataEnd()]
		);
		address tokenOut = params.tokens[params.parts[partIdx].tokenOutIdx()];
		uint256 preBalance = IERC20(tokenOut).selfBalance();
		bool success;
		(success, data) = params.parts[partIdx].getAdaptor(params.deployer).delegatecall(data);
		require(success, RevertReasonParser.parse(data));
		uint256 postBalance = IERC20(tokenOut).selfBalance();
		require(postBalance >= preBalance, "UrbRouter: negative output");
		unchecked {
			amounts[partIdx] = postBalance - preBalance;
		}
		if (!checkAmountOutMin(params, amounts, partIdx)) {
			// return revert if amountOut is insufficient
			assembly {
				revert(add(amounts, 0x20), mload(amounts))
			}
		}
	}

	function getAmountIn(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 partIdx
	) internal pure returns (uint256) {
		uint256 idx = params.parts[partIdx].amountInIdx();
		if (idx < params.amounts.length) {
			return params.amounts[idx];
		} else if (partIdx > 0x0) {
			return amounts[partIdx - 0x1];
		} else {
			revert("UrbRouter: input not provided");
		}
	}

	function checkAmountOutMin(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 partIdx
	) internal pure returns (bool) {
		uint256 idx = params.parts[partIdx].amountOutMinIdx();
		return idx > params.amounts.length || amounts[partIdx] >= params.amounts[idx];
	}
}
