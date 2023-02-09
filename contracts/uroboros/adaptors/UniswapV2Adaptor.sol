// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import '../../common/libraries/math/SafeMath.sol';
import '../../common/libraries/math/Math.sol';
import '../../uniswap-v2/interfaces/IUniswapV2Pair.sol';
import '../../common/libraries/Fee.sol';
import '../../common/libraries/Hex.sol';
import '../libraries/UniswapV2Data.sol';

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import 'hardhat/console.sol';

library UniswapV2Adaptor {
	using Fee for uint;
	using Math for uint;
	using SafeMath for uint;
	using UniswapV2Data for bytes;
	using SafeERC20 for IERC20;

	function quote(
		IERC20,
		uint256 amountIn,
		bytes memory data
	) internal view returns (uint256 amountOut) {
		amountOut = _quote(
			amountIn,
			data.pairAddress(),
			data.swapFee(),
			data.sellFee(),
			data.zeroForOne()
		);
		amountOut = data.buyFee().getAmountLessFee(amountOut);
	}

	function swap(IERC20 tokenIn, uint256 amountIn, bytes memory data, address to) internal {
		// console.log('here7');

		address addr = data.pairAddress();

		uint preBalance = tokenIn.balanceOf(addr);
		// console.log('here8');
		tokenIn.safeTransfer(addr, amountIn);
		uint postBalance = tokenIn.balanceOf(addr);

		// console.log('here9');

		amountIn = postBalance - preBalance;
		bool zeroForOne = data.zeroForOne();
		uint256 amount0Out = _quote(amountIn, addr, data.swapFee(), data.sellFee(), zeroForOne);
		uint256 amount1Out;
		if (zeroForOne) {
			(amount0Out, amount1Out) = (amount1Out, amount0Out);
		}

		// console.log('here10');

		IUniswapV2Pair(addr).swap(amount0Out, amount1Out, to, new bytes(0));
	}

	function _quote(
		uint256 amountIn,
		address addr,
		uint swapFee,
		uint sellFee,
		bool zeroForOne
	) private view returns (uint256 amountOut) {
		(uint112 reserveOut, uint112 reserveIn, ) = IUniswapV2Pair(addr).getReserves();
		if (zeroForOne) {
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}
		amountIn = sellFee.getAmountLessFee(amountIn);
		amountIn = swapFee.getAmountLessFee(amountIn);
		amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
	}

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) private pure returns (uint256) {
		require(!amountIn.isZero(), 'UniswapV2Adaptor: zero input');
		return amountIn.mul(reserveOut) / (amountIn.add(reserveIn));
	}
}
