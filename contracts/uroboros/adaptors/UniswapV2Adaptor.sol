// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "../../common/libraries/math/SafeMath.sol";
import "../../common/libraries/math/Math.sol";
import "../../uniswap-v2/interfaces/IUniswapV2Pair.sol";
import "../../common/libraries/Fee.sol";
import "../../common/libraries/Hex.sol";
import "../libraries/UniswapV2Data.sol";
import "../interfaces/IAdaptor.sol";

import "hardhat/console.sol";

contract UniswapV2Adaptor is IAdaptor {
	using Fee for uint;
	using Math for uint;
	using SafeMath for uint;
	using UniswapV2Data for bytes;

	error ZeroInput();

	function quote(address, uint256 amountIn, bytes memory data) public view returns (uint256) {
		data.check();
		return data.buyFee().getAmountLessFee(_quote(data.pairAddress(), amountIn, data));
	}

	function swap(address tokenIn, uint256 amountIn, bytes memory data, address to) public payable {
		data.check();
		address addr = data.pairAddress();
		uint256 amount0Out = _quote(addr, amountIn, data);
		uint256 amount1Out;
		if (data.zeroForOne()) {
			(amount0Out, amount1Out) = (amount1Out, amount0Out);
		}
		IERC20(tokenIn).transfer(addr, amountIn);
		IUniswapV2Pair(addr).swap(amount0Out, amount1Out, to, "");
	}

	function _quote(address addr, uint256 amountIn, bytes memory data) internal view returns (uint256) {
		(uint112 reserveOut, uint112 reserveIn, ) = IUniswapV2Pair(addr).getReserves();
		if (data.zeroForOne()) {
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}
		amountIn = data.swapFee().feeMul(data.sellFee()).getAmountLessFee(amountIn);
		uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
		return amountOut;
	}

	function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
		if (amountIn.isZero()) {
			revert ZeroInput();
		}
		return amountIn.mul(reserveOut) / (amountIn.add(reserveIn));
	}
}
