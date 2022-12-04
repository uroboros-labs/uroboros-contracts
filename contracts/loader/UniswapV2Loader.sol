// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "../uniswap-v2/UniswapV2Pair.sol";
import "../common/libraries/RevertReasonParser.sol";
import "./libraries/Wrapper.sol";
import "./libraries/FeeERC20.sol";
import "./Relay.sol";
import "hardhat/console.sol";

/// Loads UniswapV2 pair
/// pair requirements:
/// 	- reserves should equal to token balances
/// 	- full reserve can be used in swap
contract UniswapV2Loader is Proxy {
	using SafeERC20 for IERC20;
	using FeeERC20 for IERC20;
	using Fee for uint;

	Relay immutable relay;
	UniswapV2Pair immutable __pair;

	uint constant SWAP_FEE_STEP = 5;
	uint constant SWAP_FEE_MAX = 100;

	constructor(Relay _relay, UniswapV2Pair pair) {
		relay = _relay;
		__pair = pair;
		assembly {
			sstore(10, 1) // unlocked
		}
	}

	function _implementation() internal view override returns (address) {
		return address(__pair);
	}

	struct Data {
		string name;
		uint[2] reserves;
		address[2] tokens;
		uint swapFee;
		uint[2] gas;
		uint[2] buyFee;
		uint[2] sellFee;
	}

	function load(address pair) external returns (Data memory data) {
		// globally set wrapper to point to pair
		Wrapper.set(pair);

		data.name = Wrapper.name();
		(data.reserves[0], data.reserves[1], ) = Wrapper.getReserves();
		data.tokens[0] = Wrapper.token0();
		data.tokens[1] = Wrapper.token1();
		require(
			IERC20(data.tokens[0]).balanceOf(address(this)) == data.reserves[0],
			"UniswapV2Loader: balance0 != reserve0"
		);
		require(
			IERC20(data.tokens[1]).balanceOf(address(this)) == data.reserves[1],
			"UniswapV2Loader: balance1 != reserve1"
		);

		(data.buyFee[0], data.sellFee[0]) = getTransferFees(IERC20(data.tokens[0]));
		(data.buyFee[1], data.sellFee[1]) = getTransferFees(IERC20(data.tokens[1]));

		(data.swapFee, data.gas[0]) = getSwapFees(
			IERC20(data.tokens[0]),
			IERC20(data.tokens[1]),
			true,
			// data.sellFee[0],
			0
		);
		(, data.gas[1]) = getSwapFees(
			IERC20(data.tokens[1]),
			IERC20(data.tokens[0]),
			false,
			// data.sellFee[1],
			data.swapFee
		);
	}

	function getSwapFees(
		IERC20 tokenIn,
		IERC20 tokenOut,
		bool zeroForOne,
		// uint sellFee,
		uint swapFee
	) internal returns (uint, uint) {
		tokenIn.safeTransfer(address(relay), (tokenIn.balanceOf(address(this)) / 3) * 2);
		Wrapper.sync();
		(uint reserveOut, uint reserveIn, ) = Wrapper.getReserves();
		if (zeroForOne) {
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}

		console.log("preSwap:: reserveIn: %s, reserveOut: %s", reserveIn, reserveOut);
		(, uint amountIn) = relay.transferAllGetFee(tokenIn, address(this));
		// dont know why, but this better be commented
		// amountIn = sellFee.getAmountLessFee(amountIn);
		console.log("amountIn: %s", amountIn);

		for (; swapFee < SWAP_FEE_MAX; swapFee += SWAP_FEE_STEP) {
			uint amount0Out = _getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
			// console.log("amountOut: %s", amount0Out);
			uint amount1Out;

			if (zeroForOne) {
				(amount0Out, amount1Out) = (amount1Out, amount0Out);
			}

			uint gas = gasleft();
			try Wrapper.swap(amount0Out, amount1Out, address(relay), "") {
				relay.transferAllGetFee(tokenOut, address(this));
				Wrapper.sync();

				console.log("swapFee: %s", swapFee);

				(reserveIn, reserveOut, ) = Wrapper.getReserves();
				console.log("postSwap:: reserveIn: %s, reserveOut: %s", reserveIn, reserveOut);

				return (swapFee, gas - gasleft());
			} catch Error(string memory reason) {
				// console.log("error: %s", reason);
			}
		}
		revert("UniswapV2Loader: swapFeeNotReached");
	}

	function getTransferFees(IERC20 token) internal returns (uint sell, uint buy) {
		sell = token.transferGetFee(address(relay), token.balanceOf(address(this)));
		(buy, ) = relay.transferAllGetFee(token, address(this));
	}

	function _getAmountOut(
		uint amountIn,
		uint reserveIn,
		uint reserveOut,
		uint swapFee
	) internal view returns (uint) {
		amountIn = swapFee.getAmountLessFee(amountIn);
		console.log("amountInLessFee: %s", amountIn);
		return (amountIn * reserveOut) / (amountIn + reserveIn);
	}
}
