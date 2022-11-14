// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./libraries/UrbERC20.sol";
import "./libraries/RevertReasonParser.sol";
import "./libraries/Part.sol";
import "./libraries/Bitmap.sol";
import "./libraries/Math.sol";
import "./libraries/Strings2.sol";

import "hardhat/console.sol";

/// @title Uroborus Router
/// @author maksfourlife
contract UroborusRouter {
	using Part for uint256;
	using UrbDeployer for address;
	using UrbERC20 for IERC20;
	using BitMap for uint256;

	using Strings2 for uint256[][];

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

		// depth should never be greater than current depth
		uint256[][] memory tokenAmounts = new uint256[][](params.tokens.length);
		// token -> part -> {success,depth}
		// points to last part, where token was used
		uint256[] memory tokenPart = new uint256[](params.tokens.length);

		{
			uint256[] memory tokenDepths = new uint256[](params.tokens.length);
			for (uint256 i; i < params.parts.length; i++) {
				uint256 tokenInIdx = params.parts[i].tokenInIdx();
				uint256 tokenOutIdx = params.parts[i].tokenOutIdx();
				uint256 sectionDepth = params.parts[i].sectionDepth();
				tokenDepths[tokenInIdx] = Math.max(tokenDepths[tokenInIdx], sectionDepth);
				tokenDepths[tokenOutIdx] = Math.max(tokenDepths[tokenOutIdx], sectionDepth);
			}
			for (uint256 i; i < params.tokens.length; i++) {
				tokenAmounts[i] = new uint256[](tokenDepths[i] + 0x1);
			}
		}

		for (uint256 i; i < params.parts.length; ) {
			console.log("i: %s", i);

			address tokenIn;
			uint256 amountIn;
			{
				// scope for sectionDepth, {token,amount}InIdx
				uint256 tokenInIdx = params.parts[i].tokenInIdx();
				require(tokenInIdx < params.tokens.length, "UrbRouter: token index out of bounds");
				tokenIn = params.tokens[tokenInIdx];

				bool success;
				uint256 depth;
				{
					uint256 partIdx = tokenPart[tokenInIdx];
					uint256 sectionId = params.parts[partIdx].sectionId();
					success = !skipMask.get(sectionId);
					depth = params.parts[partIdx].sectionDepth();
				}

				uint256 sectionDepth = params.parts[i].sectionDepth();

				if (success && depth != sectionDepth) {
					tokenAmounts[tokenInIdx][sectionDepth] = tokenAmounts[tokenInIdx][depth];
				}

				tokenPart[tokenInIdx] = i;
				console.log("tokenAmounts: %s", tokenAmounts.toString());

				uint256 amountInIdx = params.parts[i].amountInIdx();
				if (amountInIdx >= params.amounts.length) {
					// if amountIn not provided
					amountIn = tokenAmounts[tokenInIdx][sectionDepth];
				} else {
					amountIn = params.amounts[amountInIdx];
				}

				if (!params.parts[i].isInput()) {
					require(
						tokenAmounts[tokenInIdx][sectionDepth] >= amountIn,
						"UrbRouter: insufficient input"
					);
					unchecked {
						tokenAmounts[tokenInIdx][sectionDepth] -= amountIn;
					}
				}
			}

			console.log("amountIn: %s", amountIn);

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
				tokenPart[tokenOutIdx] = i; // update token's last use
				require(tokenOutIdx < params.tokens.length, "UrbRouter: token index out of bounds");
				uint256 sectionDepth = params.parts[i].sectionDepth();
				tokenAmounts[tokenOutIdx][sectionDepth] += amounts[i];
			}

			{
				uint256 amountOutMinIdx = params.parts[i].amountOutMinIdx();
				bool success = amountOutMinIdx >= params.amounts.length ||
					amounts[i] >= params.amounts[amountOutMinIdx];
				console.log("success: %s", success);
				if (!success) {
					console.log("amountOutMin: %s", params.amounts[amountOutMinIdx]);
					skipMask = skipMask.set(params.parts[i].sectionId());
					// if we jump to end of skipped section, we don't need to skip it every time
					i = params.parts[i].sectionEnd();
				} else {
					i++;
				}
			}
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
