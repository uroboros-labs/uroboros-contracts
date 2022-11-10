// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./libraries/UrbERC20.sol";
import "./libraries/RevertReasonParser.sol";
import "./libraries/Part.sol";
import "./libraries/Bitmap.sol";
import "./libraries/Math.sol";

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
		(amounts, skipMask) = quote(params);
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

	function quote(SwapParams calldata params)
		internal
		view
		returns (uint256[] memory amounts, uint256 skipMask)
	{
		amounts = new uint256[](params.parts.length);
		uint256[][] memory tokenAmounts = new uint256[][](params.tokens.length);
		{
			// scope for maxDepth
			uint256 maxDepth;
			for (uint256 i; i < params.parts.length; i++) {
				maxDepth = Math.max(maxDepth, params.parts[i].sectionDepth());
			}
			for (uint256 i; i < tokenAmounts.length; i++) {
				tokenAmounts[i] = new uint256[](maxDepth + 0x1);
			}
		}

		uint256 depth; // most recent depth
		bool success; // most recent amountOutMin check result

		for (uint256 i; i < params.parts.length; i++) {
			if (skipMask.get(params.parts[i].sectionId())) {
				continue;
			}

			address tokenIn;
			uint256 amountIn;
			{
				// scope for sectionDepth, {token,amount}InIdx
				uint256 tokenInIdx = params.parts[i].tokenInIdx();
				require(tokenInIdx < params.tokens.length, "UrbRouter: token index out of bounds");
				tokenIn = params.tokens[tokenInIdx];

				uint256 sectionDepth = params.parts[i].sectionDepth();
				if (sectionDepth > depth) {
					tokenAmounts[tokenInIdx][sectionDepth] = tokenAmounts[tokenInIdx][depth];
				} else if (sectionDepth < depth && !success) {
					tokenAmounts[tokenInIdx][depth] = tokenAmounts[tokenInIdx][sectionDepth];
				}
				depth = sectionDepth;

				uint256 amountInIdx = params.parts[i].tokenInIdx();
				if (amountInIdx >= params.amounts.length) {
					// if amountIn not provided
					amountIn = tokenAmounts[tokenInIdx][depth];
				} else {
					amountIn = params.amounts[amountInIdx];
				}

				console.log("amountIn: %s", amountIn);
				console.log(
					"balanceIn: %s, isInput: %s",
					tokenAmounts[tokenInIdx][depth],
					params.parts[i].isInput()
				);
				if (!params.parts[i].isInput()) {
					require(
						tokenAmounts[tokenInIdx][depth] >= amountIn,
						"UrbRouter: insufficient input"
					);
					unchecked {
						tokenAmounts[tokenInIdx][depth] -= amountIn;
					}
				}
			}

			address adaptor = params.deployer.getAddress(params.parts[i].adaptorId());
			bytes memory data;
			{
				// scope for data{Start,End}
				uint256 dataStart = params.parts[i].dataStart();
				uint256 dataEnd = params.parts[i].dataEnd();
				require(dataEnd >= dataStart, "UrbRouter: negative length data");
				data = params.data[dataStart:dataEnd];
			}

			amounts[i] = IAdaptor(adaptor).quote(tokenIn, amountIn, data);
			console.log("amountOut: %s", amounts[i]);

			{
				// scope for tokenOutIdx
				uint256 tokenOutIdx = params.parts[i].tokenOutIdx();
				require(tokenOutIdx < params.tokens.length, "UrbRouter: token index out of bounds");
				tokenAmounts[tokenOutIdx][depth] += amounts[i];
			}

			uint256 amountOutMinIdx = params.parts[i].amountOutMinIdx();
			success =
				amountOutMinIdx >= params.amounts.length ||
				amounts[i] >= params.amounts[amountOutMinIdx];
			if (!success) {
				skipMask = skipMask.set(amounts[i].sectionId());
				console.log("amountOutMin: %s", params.amounts[amountOutMinIdx]);
				i = params.parts[i].sectionEnd();
			}
			console.log("success: %s", success);
			console.log("===============");
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
		require(start <= end, "UrbRouter: negative length section");
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
		uint256 i
	) internal {
		address tokenIn;
		uint256 amountIn;
		{
			// scope for balance, {token,amount}InIdx
			uint256 tokenInIdx = params.parts[i].tokenInIdx();
			require(tokenInIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenIn = params.tokens[tokenInIdx];

			uint256 amountInIdx = params.parts[i].amountInIdx();
			uint256 balance = IERC20(tokenIn).selfBalance();
			if (amountInIdx < params.amounts.length) {
				amountIn = params.amounts[amountInIdx];
				if (amountIn > balance) {
					require(params.parts[i].isInput(), "UrbRouter: insufficient input");
					unchecked {
						IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn - balance);
					}
				}
			} else {
				amountIn = balance;
			}
		}

		bytes memory data;
		{
			// scope for data{Start,End}
			uint256 dataStart = params.parts[i].dataStart();
			uint256 dataEnd = params.parts[i].dataEnd();
			require(dataEnd >= dataStart, "UrbRouter: negative length data");
			data = params.data[dataStart:dataEnd];
		}
		data = abi.encodeWithSelector(IAdaptor.swap.selector, tokenIn, amountIn, data);

		address tokenOut;
		{
			// scope for tokenOutIdx
			uint256 tokenOutIdx = params.parts[i].tokenOutIdx();
			require(tokenOutIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenOut = params.tokens[tokenOutIdx];
		}

		address adaptor = UrbDeployer.getAddress(params.deployer, params.parts[i].adaptorId());

		{
			// scope for success, {post,pre}Balance
			uint256 preBalance = IERC20(tokenOut).selfBalance();

			bool success;
			(success, data) = adaptor.delegatecall(data);
			require(success, RevertReasonParser.parse(data));

			uint256 postBalance = IERC20(tokenOut).selfBalance();
			require(postBalance >= preBalance, "UrbRouter: negative output");
			unchecked {
				amounts[i] = postBalance - preBalance;
			}
		}

		if (!checkAmountOutMin(params, amounts, i)) {
			// return revert if amountOut is insufficient
			data = abi.encode(amounts);
			assembly {
				revert(add(data, 0x20), mload(data))
			}
		}
	}

	function checkAmountOutMin(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 partIdx
	) internal pure returns (bool) {
		uint256 idx = params.parts[partIdx].amountOutMinIdx();
		return idx >= params.amounts.length || amounts[partIdx] >= params.amounts[idx];
	}
}
