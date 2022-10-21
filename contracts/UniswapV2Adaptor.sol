// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

import "./interfaces/IAdaptor.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/Fee.sol";
import "./libraries/UniswapV2Data.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract UniswapV2Adaptor is IAdaptor {
	using Fee for uint256;
	using UniswapV2Data for bytes;

	function quote(
		address,
		uint256 amountIn,
		bytes memory data
	) public view returns (uint256) {
		return _quote(data.pair(), amountIn, data);
	}

	function swap(
		address tokenIn,
		uint256 amountIn,
		bytes memory data
	) external payable {
		address addr = data.pair();
		uint256 amount0Out;
		uint256 amount1Out = _quote(addr, amountIn, data);
		if (data.rev()) {
			(amount0Out, amount1Out) = (amount1Out, amount0Out);
		}
		IERC20(tokenIn).transfer(addr, amountIn);
		IUniswapV2Pair(addr).swap(amount0Out, amount1Out, address(this), "");
	}

	function _quote(
		address addr,
		uint256 amountIn,
		bytes memory data
	) internal view returns (uint256) {
		(uint112 reserveIn, uint112 reserveOut, ) = IUniswapV2Pair(addr).getReserves();
		if (data.rev()) {
			(reserveIn, reserveOut) = (reserveOut, reserveIn);
		}
		amountIn = Fee.mul(data.swapFee(), data.sellFee()).getAmountLessFee(amountIn);
		uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
		return amountOut;
	}

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure returns (uint256) {
		return (amountIn * reserveOut) / (amountIn + reserveIn);
	}
}
