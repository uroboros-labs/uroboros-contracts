// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "../common/RescueFunds.sol";
import "../common/libraries/math/Math.sol";
import "../common/libraries/SafeCast.sol";
import "../common/libraries/RevertReasonParser.sol";
import "../common/libraries/Bitmap.sol";
import "../common/libraries/Strings2.sol";
import "../common/libraries/Bytes.sol";

import "./libraries/UrbERC20.sol";
import "./libraries/Part.sol";
import "./libraries/TokenId.sol";

import "./interfaces/IAdaptor.sol";

import "hardhat/console.sol";

contract UrbRouter is RescueFunds {
	using UrbDeployer for address;

	using UrbERC20 for IERC20;
	using SafeERC20 for IERC20;

	using Bytes for bytes;
	using SafeCast for bytes32;
	using BitMap for uint256;
	using Part for uint256;
	using TokenId for uint256;

	using Math for uint256;

	using Strings2 for uint256[][];

	event Error(string reason);

	struct SwapParams {
		address deployer;
		uint256[] parts;
		bytes data;
	}

	function swap(SwapParams calldata params)
		external
		payable
		returns (
			uint256[] memory amounts,
			uint256 skipMask,
			uint256 gasUsed
		)
	{
		gasUsed = gasleft();
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
		if (success || RevertReasonParser.getType(data) == RevertReasonParser.ErrorType.Unknown) {
			amounts = abi.decode(data, (uint256[]));
			uint256 numTokens;
			for (uint256 i; i < params.parts.length; i++) {
				uint256 tokenInId = params.parts[i].tokenInId();
				uint256 tokenOutId = params.parts[i].tokenOutId();
				numTokens = Math.max(numTokens, tokenInId);
				numTokens = Math.max(numTokens, tokenOutId);
			}
			for (uint256 i; i <= numTokens; i++) {
				address token = params.data.valueAt(i.toTokenPtr()).toLeAddress();
				uint256 balance = IERC20(token).selfBalance();
				if (balance.isZero()) {
					IERC20(token).safeTransfer(msg.sender, balance);
				}
			}
		} else {
			revert(RevertReasonParser.parse(data));
		}
		gasUsed -= gasleft();
	}

	function quote(SwapParams calldata params)
		internal
		view
		returns (uint256[] memory amounts, uint256 skipMask)
	{
		amounts = new uint256[](params.parts.length);

		uint256[][] memory tokenAmounts;
		{
			uint256 numTokens;
			for (uint256 i; i < params.parts.length; i++) {
				numTokens = Math.max(numTokens, params.parts[i].tokenInId());
				numTokens = Math.max(numTokens, params.parts[i].tokenOutId());
			}
			numTokens++;
			tokenAmounts = new uint256[][](numTokens);
		}
		// token -> part -> {success,depth}
		// points to last part, where token was used
		uint256[] memory tokenPart = new uint256[](tokenAmounts.length);

		{
			uint256[] memory tokenDepths = new uint256[](tokenAmounts.length);
			for (uint256 i; i < params.parts.length; i++) {
				uint256 tokenInId = params.parts[i].tokenInId();
				uint256 tokenOutId = params.parts[i].tokenOutId();
				uint256 sectionDepth = params.parts[i].sectionDepth();
				tokenDepths[tokenInId] = Math.max(tokenDepths[tokenInId], sectionDepth);
				tokenDepths[tokenOutId] = Math.max(tokenDepths[tokenOutId], sectionDepth);
			}
			for (uint256 i; i < tokenAmounts.length; i++) {
				tokenAmounts[i] = new uint256[](tokenDepths[i] + 0x1);
			}
		}

		for (uint256 i; i < params.parts.length; ) {
			console.log("i: %s", i);

			address tokenIn;
			uint256 amountIn;
			{
				// scope for sectionDepth, {token,amount}InIdx
				uint256 tokenInId = params.parts[i].tokenInId();
				console.log("tokenInId: %s", tokenInId);
				// require(tokenInPtr < tokenAmounts.length, "UrbRouter: token index out of bounds");
				// tokenIn = params.tokens[tokenInIdx];
				tokenIn = params.data.valueAt(tokenInId.toTokenPtr()).toLeAddress();
				console.log("tokenIn: %s", tokenIn);

				bool success;
				uint256 depth;
				{
					uint256 partIdx = tokenPart[tokenInId];
					// uint256 partIdx = params.parts[i].tokenInLastUsedIdx();
					uint256 sectionId = params.parts[partIdx].sectionId();
					success = !skipMask.get(sectionId);
					depth = params.parts[partIdx].sectionDepth();
				}

				uint256 sectionDepth = params.parts[i].sectionDepth();

				if (success && depth != sectionDepth) {
					tokenAmounts[tokenInId][sectionDepth] = tokenAmounts[tokenInId][depth];
				}

				tokenPart[tokenInId] = i;
				console.log("tokenAmounts: %s", tokenAmounts.toString());

				uint256 amountInPtr = params.parts[i].amountInPtr();
				console.log("amountInPtr: %s", amountInPtr);
				if (amountInPtr.isZero()) {
					// if amountIn not provided
					amountIn = tokenAmounts[tokenInId][sectionDepth];
				} else {
					amountIn = params.data.valueAt(amountInPtr).toUint();
				}
				console.log("amountIn: %s", amountIn);

				if (!params.parts[i].isInput()) {
					require(
						tokenAmounts[tokenInId][sectionDepth] >= amountIn,
						"UrbRouter: insufficient input"
					);
					unchecked {
						tokenAmounts[tokenInId][sectionDepth] -= amountIn;
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
				uint256 tokenOutId = params.parts[i].tokenOutId();
				tokenPart[tokenOutId] = i; // update token's last use
				uint256 sectionDepth = params.parts[i].sectionDepth();
				tokenAmounts[tokenOutId][sectionDepth] += amounts[i];
			}

			{
				uint256 amountOutMinPtr = params.parts[i].amountOutMinPtr();
				console.log("amountOutMinPtr: %s", amountOutMinPtr);
				uint256 amountOutMin = params.data.valueAt(amountOutMinPtr).toUint();
				console.log("amountOutMin: %s", amountOutMin);
				bool success = amountOutMinPtr.isZero() || amounts[i] >= amountOutMin;
				if (!success) {
					console.log("success: false");
					skipMask = skipMask.set(params.parts[i].sectionId());
					// if we jump to end of skipped section, we don't need to skip it every time
					i = params.parts[i].sectionEnd();
				} else {
					console.log("success: true");
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

				RevertReasonParser.ErrorType errorType = RevertReasonParser.getType(data);
				if (success || errorType == RevertReasonParser.ErrorType.Unknown) {
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
			uint256 tokenInId = params.parts[i].tokenInId();
			// require(tokenInIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenIn = params.data.valueAt(tokenInId.toTokenPtr()).toLeAddress();

			uint256 balance = IERC20(tokenIn).selfBalance();
			uint256 amountInPtr = params.parts[i].amountInPtr();
			if (amountInPtr.isZero()) {
				amountIn = balance;
			} else {
				amountIn = params.data.valueAt(amountInPtr).toUint();
				if (amountIn > balance) {
					require(params.parts[i].isInput(), "UrbRouter: insufficient input");
					unchecked {
						IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn - balance);
					}
				}
			}
		}

		address tokenOut;
		{
			// scope for tokenOutIdx
			uint256 tokenOutId = params.parts[i].tokenOutId();
			// require(tokenOutIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenOut = params.data.valueAt(tokenOutId.toTokenPtr()).toLeAddress();
		}

		address adaptor = UrbDeployer.getAddress(params.deployer, params.parts[i].adaptorId());

		bytes memory data;
		{
			// scope for data{Start,End}
			uint256 dataStart = params.parts[i].dataStart();
			uint256 dataEnd = params.parts[i].dataEnd();
			require(dataEnd >= dataStart, "UrbRouter: negative length data");
			data = params.data[dataStart:dataEnd];
		}
		address to = params.parts[i].isOutput() ? msg.sender : address(this);
		data = abi.encodeWithSelector(IAdaptor.swap.selector, tokenIn, amountIn, data, to);

		{
			// scope for success, {post,pre}Balance
			uint256 preBalance = IERC20(tokenOut).balanceOf(to);

			bool success;
			(success, data) = adaptor.delegatecall(data);
			if (!success) {
				assembly {
					revert(add(data, 0x20), mload(data))
				}
			}

			uint256 postBalance = IERC20(tokenOut).balanceOf(to);

			require(postBalance >= preBalance, "UrbRouter: negative output");
			unchecked {
				amounts[i] = postBalance - preBalance;
			}
		}

		{
			uint256 amountOutMinPtr = params.parts[i].amountOutMinPtr();
			bool success = amountOutMinPtr.isZero() ||
				amounts[i] >= params.data.valueAt(amountOutMinPtr).toUint();
			if (!success) {
				data = abi.encode(amounts);
				assembly {
					revert(add(data, 0x20), mload(data))
				}
			}
		}
	}
}
