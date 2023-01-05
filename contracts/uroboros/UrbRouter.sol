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
		address deployer; // adaptor deployer, used to calculate adaptor address
		uint256[] parts; // various indexes and flags used in a route, decoded by Part library
		bytes data; // payload with tokens, amounts, addresses and swap data packed tightly
	}

	/// Sequentially and recursively executes complex routes
	/// @return amounts actual tokens amounts after route execution
	/// @return skipMask stores bits of skipped route parts
	/// @return gasUsed rough gas used during execution
	function swap(
		SwapParams calldata params
	) external payable returns (uint256[] memory amounts, uint256 skipMask, uint256 gasUsed) {
		console.log("msg.sender: %s", msg.sender);
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
		// may revert with either amounts, either error
		if (success || RevertReasonParser.getType(data) == RevertReasonParser.ErrorType.Unknown) {
			amounts = abi.decode(data, (uint256[]));
			uint numTokens = getNumTokens(params.parts);
			sendLeftovers(numTokens, params.data);
		} else {
			revert(RevertReasonParser.parse(data));
		}
		gasUsed -= gasleft();
	}

	function sendLeftovers(uint numTokens, bytes calldata data) internal {
		for (uint256 i; i <= numTokens; i++) {
			address token = data.valueAt(i.toTokenPtr()).toLeAddress();
			uint256 balance = IERC20(token).selfBalance();
			// if the're is leftover (cashbacks) it's send to msg.sender
			if (!balance.isZero()) {
				IERC20(token).safeTransfer(msg.sender, balance);
			}
		}
	}

	/// Counts tokens in route by iterating over route parts
	function getNumTokens(uint[] calldata parts) internal pure returns (uint numTokens) {
		for (uint256 i; i < parts.length; i++) {
			uint256 tokenInId = parts[i].tokenInId();
			uint256 tokenOutId = parts[i].tokenOutId();
			numTokens = Math.max(numTokens, tokenInId);
			numTokens = Math.max(numTokens, tokenOutId);
		}
		numTokens++;
	}

	function setupAmountsAndParts(
		SwapParams calldata params
	) internal pure returns (uint[][] memory tokenAmounts, uint[] memory tokenPart) {
		uint numTokens = getNumTokens(params.parts);

		tokenAmounts = new uint256[][](numTokens);
		// token -> part -> {success,depth}
		// points to last part, where token was used
		tokenPart = new uint256[](tokenAmounts.length);

		// calculates and sets max depth for each token
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

	function getData(uint part, bytes calldata data) internal pure returns (bytes memory) {
		uint256 dataStart = part.dataStart();
		uint256 dataEnd = part.dataEnd();
		require(dataEnd >= dataStart, "UrbRouter: NegativeLengthData");
		return data[dataStart:dataEnd];
	}

	/// Dry-runs route
	function quote(
		SwapParams calldata params
	) public view returns (uint256[] memory amounts, uint256 skipMask) {
		amounts = new uint256[](params.parts.length);

		(uint[][] memory tokenAmounts, uint[] memory tokenPart) = setupAmountsAndParts(params);

		for (uint256 i; i < params.parts.length; ) {
			address tokenIn;
			uint256 amountIn;
			{
				// scope for sectionDepth, {token,amount}InIdx
				uint256 tokenInId = params.parts[i].tokenInId();

				tokenIn = params.data.valueAt(tokenInId.toTokenPtr()).toLeAddress();

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

				// if previous part executed successfully and current part is not in the same segment, copy amount
				if (success && depth != sectionDepth) {
					tokenAmounts[tokenInId][sectionDepth] = tokenAmounts[tokenInId][depth];
				}

				// update tokens' last reffered part
				tokenPart[tokenInId] = i;

				uint256 amountInPtr = params.parts[i].amountInPtr();
				if (amountInPtr.isZero()) {
					// if amountIn not provided it's copied from current depth available balance
					amountIn = tokenAmounts[tokenInId][sectionDepth];
				} else {
					amountIn = params.data.valueAt(amountInPtr).toUint();
				}

				console.log("amountIn: %s", amountIn);
				console.log("balance: %s", tokenAmounts[tokenInId][sectionDepth]);

				if (!params.parts[i].isInput()) {
					require(
						tokenAmounts[tokenInId][sectionDepth] >= amountIn,
						"UrbRouter.quote: InsufficientInput"
					);
					unchecked {
						tokenAmounts[tokenInId][sectionDepth] -= amountIn;
					}
				}
			}

			address adaptor = params.deployer.getAddress(params.parts[i].adaptorId());
			bytes memory data = getData(params.parts[i], params.data);

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
				uint256 amountOutMin = params.data.valueAt(amountOutMinPtr).toUint();
				if (!amountOutMinPtr.isZero()) {
					console.log("amountOutMin: %s", amountOutMin);
				}
				bool success = amountOutMinPtr.isZero() || amounts[i] >= amountOutMin;
				if (!success) {
					console.log("success: false");
					skipMask = skipMask.set(params.parts[i].sectionId());
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
		require(start <= end, "UrbRouter: NegativeLengthSection");
		console.log("section:: start: %s, end: %s, depth: %s", start, end, depth);
		for (uint256 i = start; i < end; ) {
			if (skipMask.get(params.parts[i].sectionId())) {
				i++;
				continue;
			}
			if (params.parts[i].sectionDepth() > depth) {
				console.log("sectionDepth > depth");
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
				console.log("swapPart");
				swapPart(params, amounts, i++);
			}
		}
		return amounts;
	}

	function swapPart(SwapParams calldata params, uint256[] memory amounts, uint256 i) internal {
		address tokenIn;
		uint256 amountIn;
		{
			// scope for balance, {token,amount}InIdx
			uint256 tokenInId = params.parts[i].tokenInId();
			// require(tokenInIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenIn = params.data.valueAt(tokenInId.toTokenPtr()).toLeAddress();
			console.log("tokenIn: %s", tokenIn);

			uint256 balance = IERC20(tokenIn).selfBalance();
			console.log("selfBalance: %s", balance);
			uint256 amountInPtr = params.parts[i].amountInPtr();
			if (amountInPtr.isZero()) {
				amountIn = balance;
			} else {
				amountIn = params.data.valueAt(amountInPtr).toUint();
				console.log("amountIn: %s", amountIn);
				console.log("msg.sender: %s", msg.sender);
				console.log("senderBalance: %s", IERC20(tokenIn).balanceOf(msg.sender));
				if (amountIn > balance) {
					require(params.parts[i].isInput(), "UrbRouter.swap: InsufficientInput");
					unchecked {
						IERC20(tokenIn).safeTransferFrom(
							msg.sender,
							address(this),
							amountIn - balance
						);
					}
				}
			}
			console.log("amountIn: %s", amountIn);
		}

		address tokenOut;
		{
			// scope for tokenOutIdx
			uint256 tokenOutId = params.parts[i].tokenOutId();
			// require(tokenOutIdx < params.tokens.length, "UrbRouter: token index out of bounds");
			tokenOut = params.data.valueAt(tokenOutId.toTokenPtr()).toLeAddress();
		}

		address adaptor = UrbDeployer.getAddress(params.deployer, params.parts[i].adaptorId());
		bytes memory data = getData(params.parts[i], params.data);

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

			require(postBalance >= preBalance, "UrbRouter: NegativeOutput");
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
