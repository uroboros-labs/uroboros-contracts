// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../../common/libraries/math/SafeMath.sol";
import "../../common/libraries/math/Math.sol";
import "../../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "../../common/libraries/Fee.sol";
import "../../common/libraries/Hex.sol";
import "../libraries/UniswapV2Data.sol";

import "hardhat/console.sol";

library UniswapV2Adaptor {
	using Fee for uint;
	using Math for uint;
	using SafeMath for uint;
	using UniswapV2Data for bytes;

	struct SwapData {
		address pair;
		uint _flags; // contains swapFee, .., zeroForOne
	}

	function quote(address, uint256 amountIn, bytes memory data) internal view returns (uint256) {
		data.check();
		return data.buyFee().getAmountLessFee(_quote(data.pairAddress(), amountIn, data));
	}

	function swap(address tokenIn, uint256 amountIn, bytes memory data, address to) internal {
		data.check();
		// console.log("================");
		// console.log("data: %s", Hex.toHex(data));
		address addr = data.pairAddress();
		// console.log("pair: %s", addr);
		// console.log("zeroForOne: %s", data.zeroForOne());

		uint preBalance = IERC20(tokenIn).balanceOf(addr);
		IERC20(tokenIn).transfer(addr, amountIn);
		uint postBalance = IERC20(tokenIn).balanceOf(addr);

		// console.log("tokenIn: %s", tokenIn);
		// console.log("token0: %s", IUniswapV2Pair(addr).token0());
		// console.log("token1: %s", IUniswapV2Pair(addr).token1());

		amountIn = postBalance - preBalance;
		// console.log("amountIn: %s", amountIn);

		// oneForZero
		uint256 amount0Out = _quote(addr, amountIn, data);
		uint256 amount1Out;
		if (data.zeroForOne()) {
			(amount0Out, amount1Out) = (amount1Out, amount0Out);
		}

		// console.log("amount0Out: %s", amount0Out);
		// console.log("amount1Out: %s", amount1Out);
		IUniswapV2Pair(addr).swap(amount0Out, amount1Out, to, "");
	}

	function _quote(address addr, uint256 amountIn, bytes memory data) private view returns (uint256) {
		// oneForZero 0->1
		// reserve0, reserve1
		(uint112 reserveOut, uint112 reserveIn, ) = IUniswapV2Pair(addr).getReserves();
		if (data.zeroForOne()) {
			// console.log("reserves swapped");
			// zeroForOne
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}
		// console.log("swapFee: %s", data.swapFee());
		amountIn = data.swapFee().feeMul(data.sellFee()).getAmountLessFee(amountIn);
		uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
		return amountOut;
	}

	function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
		require(!amountIn.isZero(), "UniswapV2Adaptor: zero input");
		return amountIn.mul(reserveOut) / (amountIn.add(reserveIn));
	}
}
