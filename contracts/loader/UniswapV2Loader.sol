// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "./libraries/Wrapper.sol";
import "./libraries/FeeERC20.sol";
import "./Relay.sol";

/// Loads UniswapV2 pair
/// pair requirements:
/// 	- reserves should equal to token balances
/// 	- full reserve can be used in swap
contract UniswapV2Loader {
	using SafeERC20 for IERC20;
	using FeeERC20 for IERC20;
	using Fee for uint;

	/// helper for sending tokens back and forth to count fees
	Relay immutable relay;
	/// used for testing purposes in hardhat project
	address immutable __pair;

	uint8 constant SWAP_FEE_STEP = 5;
	uint8 constant SWAP_FEE_MAX = 100;

	constructor(Relay _relay, address pair) {
		relay = _relay;
		__pair = pair;
		// store UniswapV2Pair 'unlocked' flag at slot 10
		assembly {
			sstore(10, 1)
		}
	}

	struct Data {
		string name;
		uint112 reserve0;
		uint112 reserve1;
		IERC20 token0;
		IERC20 token1;
		// fees
		uint8 swap;
		// token transfer fees, measured by trasnferring token from and to pair
		uint16 buy0;
		uint16 buy1;
		uint16 sell0;
		uint16 sell1;
		// gas to perform as swap, measured before and immediately after swap
		uint64 gas01;
		uint64 gas10;
	}

	function load(address pair) external returns (Data memory data) {
		// globally sets wrapper to point to pair
		Wrapper.set(pair);

		data.name = Wrapper.name();
		(data.reserve0, data.reserve1, ) = Wrapper.getReserves();

		data.token0 = IERC20(Wrapper.token0());
		data.token1 = IERC20(Wrapper.token1());

		(data.buy0, data.sell0) = getTransferFees(data.token0, data.reserve0);
		(data.buy1, data.sell1) = getTransferFees(data.token1, data.reserve1);

		(data.swap, data.gas01) = getSwapFees(data.token0, data.token1, true, 0);
		(, data.gas10) = getSwapFees(data.token1, data.token0, false, data.swap);
	}

	/// Transfers provided token from and to pair, gets sell and buy fees
	/// @param token token to count fees for
	/// @param reserve declared token amount on pair - also checks if it equals balance
	function getTransferFees(
		IERC20 token,
		uint256 reserve
	) internal returns (uint16 buy, uint16 sell) {
		buy = token.transferGetFee(address(relay), reserve);
		(sell, ) = relay.transferAllGetFee(token, address(this));
	}

	/// Gets pair swap fee (if not provided) and gas usage
	/// Transfer 9/10 token reserve to relay, fixes price and then back
	function getSwapFees(
		IERC20 tokenIn,
		IERC20 tokenOut,
		bool zeroForOne,
		uint8 swapFee
	) internal returns (uint8, uint64) {
		// transfer 9/10 of pair reserve from it and sync - change price
		uint amountIn = (tokenIn.balanceOf(address(this)) / 10) * 9;
		tokenIn.safeTransfer(address(relay), amountIn);
		Wrapper.sync();

		// get reserves and sort them
		(uint reserveOut, uint reserveIn, ) = Wrapper.getReserves();
		if (zeroForOne) {
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}

		// transfer token back, like we selling it (pair thinks it's amountIn)
		(, amountIn) = relay.transferAllGetFee(tokenIn, address(this));

		// try to swap, successively increasing fee, until it finally swaps
		for (; swapFee < SWAP_FEE_MAX; swapFee += SWAP_FEE_STEP) {
			uint amount0Out = _getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
			uint amount1Out;

			if (zeroForOne) {
				(amount0Out, amount1Out) = (amount1Out, amount0Out);
			}

			// measure gas before and immediately after swap
			uint gasUsed = gasleft();
			try Wrapper.swap(amount0Out, amount1Out, address(relay), "") {
				gasUsed -= gasleft();

				// transfer token back to rollback price (roughly)
				relay.transferAllGetFee(tokenOut, address(this));
				Wrapper.sync();

				return (swapFee, uint64(gasUsed));
			} catch {}
		}

		revert("UniswapV2Loader: swapFeeNotReached");
	}

	function _getAmountOut(
		uint amountIn,
		uint reserveIn,
		uint reserveOut,
		uint swapFee
	) internal pure returns (uint) {
		amountIn = swapFee.getAmountLessFee(amountIn);
		return (amountIn * reserveOut) / (amountIn + reserveIn);
	}

	/// Proxies calls to uniwap pair, used in hardhat project to set storage
	fallback() external {
		address pair = __pair;
		assembly {
			let size := calldatasize()
			calldatacopy(0x0, 0x0, size)
			let ok := delegatecall(gas(), pair, 0x0, size, 0x0, 0x0)
			size := returndatasize()
			returndatacopy(0x0, 0x0, size)
			if ok {
				return(0x0, size)
			}
			revert(0x0, size)
		}
	}
}
