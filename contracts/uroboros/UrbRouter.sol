// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "../common/RescueFunds.sol";
import "../common/libraries/math/Math.sol";
import "../common/libraries/SafeCast.sol";
import "../common/libraries/RevertReasonParser.sol";
import "../common/libraries/Bitmap.sol";
import "../common/libraries/Strings2.sol";
import "../common/libraries/Bytes.sol";
import "../common/libraries/Hex.sol";

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
	using Hex for *;

	using Math for uint256;

	using Strings2 for *;
	using RevertReasonParser for bytes;

	event Error(string reason);

	error InsufficientInput();
	/// Balance after swap is less than before
	error NegativeOutput();
	error NegativeLengthData();
	error NegativeLengthSection();
	error Amounts(uint[]);

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
		gasUsed = gasleft();
		(amounts, skipMask) = quote(params);
		swapSection(params, amounts, skipMask, 0, params.parts.length, 0, revertBytes);
		console.log("here10");
		sendLeftovers(getNumTokens(params.parts), params.data);
		console.log("here11");
		gasUsed -= gasleft();
	}

	/// Iterates tokens in data and sends to msg.sender if balanceOf(this) > 0
	/// @param numTokens number of tokens to iterate, should be less or equal to actual length
	/// @param data route data to iterate tokens in (go at the start)
	function sendLeftovers(uint numTokens, bytes calldata data) internal {
		console.log("numTokens: %s", numTokens);
		for (uint256 i; i < numTokens; i++) {
			address token = data.valueAt(i.toTokenPtr()).toLeAddress();
			uint256 balance = IERC20(token).selfBalance();
			console.log("token: %s, balance: %s", token, balance);
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

	function getData(uint part, bytes calldata data) internal pure returns (bytes calldata) {
		uint256 dataStart = part.dataStart();
		uint256 dataEnd = part.dataEnd();
		if (dataStart > dataEnd) {
			revert NegativeLengthData();
		}
		return data[dataStart:dataEnd];
	}

	/// Finds and checks tokenIn and amoutIn for quote
	function getInput(
		SwapParams calldata params,
		uint[] memory tokenPart,
		uint[][] memory tokenAmounts,
		uint skipMask,
		uint i
	) internal pure returns (address tokenIn, uint amountIn) {
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

		if (!params.parts[i].isInput()) {
			if (tokenAmounts[tokenInId][sectionDepth] < amountIn) {
				revert InsufficientInput();
			}
			unchecked {
				tokenAmounts[tokenInId][sectionDepth] -= amountIn;
			}
		}
	}

	function setOutput(
		SwapParams calldata params,
		uint[] memory amounts,
		uint[] memory tokenPart,
		uint[][] memory tokenAmounts,
		uint i
	) internal pure {
		uint256 tokenOutId = params.parts[i].tokenOutId();
		tokenPart[tokenOutId] = i; // update token's last use
		uint256 sectionDepth = params.parts[i].sectionDepth();
		tokenAmounts[tokenOutId][sectionDepth] += amounts[i];
	}

	/// @return skipMaskOut
	/// @return iOut
	function checkAmountOut(
		SwapParams calldata params,
		uint[] memory amounts,
		uint skipMask,
		uint i
	) internal pure returns (uint, uint) {
		uint256 amountOutMinPtr = params.parts[i].amountOutMinPtr();
		uint256 amountOutMin = params.data.valueAt(amountOutMinPtr).toUint();
		bool success = amountOutMinPtr.isZero() || amounts[i] >= amountOutMin;
		if (!success) {
			skipMask = skipMask.set(params.parts[i].sectionId());
			i = params.parts[i].sectionEnd();
		} else {
			i++;
		}
		return (skipMask, i);
	}

	function quote(
		SwapParams calldata params
	) public view returns (uint256[] memory amounts, uint256 skipMask) {
		amounts = new uint256[](params.parts.length);

		(uint[][] memory tokenAmounts, uint[] memory tokenPart) = setupAmountsAndParts(params);

		for (uint256 i; i < params.parts.length; ) {
			// 1. get input and check
			// 2. get adaptor and data
			// 3. call adaptor and get out amount
			// 4. save out amount and check it

			(address tokenIn, uint amountIn) = getInput(
				params,
				tokenPart,
				tokenAmounts,
				skipMask,
				i
			);

			address adaptor = params.deployer.getAddress(params.parts[i].adaptorId());
			bytes memory data = getData(params.parts[i], params.data);

			amounts[i] = IAdaptor(adaptor).quote(tokenIn, amountIn, data);

			setOutput(params, amounts, tokenPart, tokenAmounts, i);
			(skipMask, i) = checkAmountOut(params, amounts, skipMask, i);
		}
	}

	function swapSection(
		SwapParams calldata params,
		uint[] memory amounts,
		uint skipMask,
		uint start,
		uint end,
		uint depth,
		function(bytes memory) errHandler
	) internal {
		bytes memory data = abi.encodeWithSelector(
			this.__swapSection.selector,
			params,
			amounts,
			skipMask,
			start,
			end,
			depth
		);
		bytes4 amountsSelector = Amounts.selector;
		bytes4 errSelector;
		uint selectorMask = ((1 << 32) - 1) << 224;
		bool ok;
		assembly {
			let data_ptr := add(data, 0x20)
			// delegate call to this with data
			ok := delegatecall(gas(), address(), data_ptr, mload(data), 0x0, 0x0)
			// copy return data to input
			let size := returndatasize()
			mstore(data, size)
			returndatacopy(data_ptr, 0, size)
			if not(ok) {
				errSelector := and(mload(data_ptr), selectorMask)
				if eq(amountsSelector, errSelector) {
					// copy return data and trim error selector
					size := sub(size, 0x4)
					mstore(data, size)
					returndatacopy(data_ptr, 0x4, size)
					ok := true
				}
			}
		}
		console.log("err_selector: %s", uint(bytes32(selectorMask)).toHex());
		console.log("err_selector: %s", uint(bytes32(errSelector)).toHex());
		console.log("amounts_selector: %s", uint(bytes32(amountsSelector)).toHex());
		console.log("ok: %s", ok);
		console.log("data: %s", data.toHex());
		console.log("data.parse: %s", data.parse());
		if (ok) {
			uint[] memory outAmounts = abi.decode(data, (uint256[]));
			console.log("outAmounts: %s", outAmounts.toString());
			for (uint i; i < amounts.length; i++) {
				amounts[i] = outAmounts[i];
			}
		} else {
			console.log("err = data");
			errHandler(data);
		}
	}

	function __swapSection(
		SwapParams calldata params,
		uint256[] memory amounts,
		uint256 skipMask,
		uint256 start,
		uint256 end,
		uint256 depth
	) external returns (uint256[] memory) {
		if (start >= end) {
			revert NegativeLengthSection();
		}
		console.log("here1");
		while (start < end) {
			if (skipMask.get(params.parts[start].sectionId())) {
				start++;
				continue;
			}
			console.log("here2");
			uint sectionDepth = params.parts[start].sectionDepth();
			if (sectionDepth > depth) {
				console.log("here3");
				uint256 sectionEnd = params.parts[start].sectionEnd();
				swapSection(params, amounts, skipMask, start, sectionEnd, sectionDepth, emitErr);
				start = sectionEnd;
			} else {
				swapPart(params, amounts, start++);
			}
		}
		return amounts;
	}

	/// @notice uses msg.sender to transfer tokens, later sender should be provided in SwapParams
	function swapPart(SwapParams calldata params, uint256[] memory amounts, uint256 i) internal {
		console.log("here4");
		address tokenIn;
		uint256 amountIn;
		{
			// scope for balance, {token,amount}InIdx
			uint256 tokenInId = params.parts[i].tokenInId();
			tokenIn = params.data.valueAt(tokenInId.toTokenPtr()).toLeAddress();

			uint256 balance = IERC20(tokenIn).selfBalance();
			uint256 amountInPtr = params.parts[i].amountInPtr();
			if (amountInPtr.isZero()) {
				amountIn = balance;
			} else {
				amountIn = params.data.valueAt(amountInPtr).toUint();
				if (amountIn > balance) {
					if (!params.parts[i].isInput()) {
						revert InsufficientInput();
					}
					console.log(
						"transferFrom(%s, %s, %s)",
						msg.sender,
						address(this),
						amountIn - balance
					);
					unchecked {
						IERC20(tokenIn).safeTransferFrom(
							msg.sender,
							address(this),
							amountIn - balance
						);
					}
				}
			}
		}
		console.log("here5");

		address tokenOut;
		{
			// scope for tokenOutIdx
			uint256 tokenOutId = params.parts[i].tokenOutId();
			tokenOut = params.data.valueAt(tokenOutId.toTokenPtr()).toLeAddress();
		}
		console.log("here6");

		address adaptor = UrbDeployer.getAddress(params.deployer, params.parts[i].adaptorId());
		bytes memory data = getData(params.parts[i], params.data);

		address to = params.parts[i].isOutput() ? msg.sender : address(this);
		data = abi.encodeWithSelector(IAdaptor.swap.selector, tokenIn, amountIn, data, to);

		console.log("here7");

		{
			// scope for success, {post,pre}Balance
			uint256 preBalance = IERC20(tokenOut).balanceOf(to);

			bool success;
			(success, data) = adaptor.delegatecall(data);
			if (!success) {
				// revert LowLevelError(data.parse());
				revertBytes(data);
			}

			uint256 postBalance = IERC20(tokenOut).balanceOf(to);

			if (postBalance < preBalance) {
				revert NegativeOutput();
			}
			unchecked {
				amounts[i] = postBalance - preBalance;
			}
		}

		console.log("here8");

		{
			uint256 amountOutMinPtr = params.parts[i].amountOutMinPtr();
			bool success = amountOutMinPtr.isZero() ||
				amounts[i] >= params.data.valueAt(amountOutMinPtr).toUint();
			if (!success) {
				revert Amounts(amounts);
			}
		}

		console.log("here9");
	}

	function emitErr(bytes memory err) internal {
		emit Error(err.parse());
	}
}

function revertBytes(bytes memory data) pure {
	assembly {
		let data_len := mload(data)
		let data_ptr := add(data, 0x20)
		revert(data_ptr, data_len)
	}
}
