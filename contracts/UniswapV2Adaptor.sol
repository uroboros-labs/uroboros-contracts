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
		// bytes32 x;
		// assembly {
		// 	x := mload(add(0x20, data))
		// }
		// console.log("x: %s", Strings.toHexString(uint256(x)));
		return _quote(data.pair(), amountIn, data);
	}

	function swap(
		address,
		uint256 amountIn,
		bytes memory data,
		address receiver
	) external payable {
		address addr = data.pair();
		uint256 amount0Out = _quote(addr, amountIn, data);
		uint256 amount1Out;
		if (data.rev()) {
			(amount0Out, amount1Out) = (amount1Out, amount0Out);
		}
		IUniswapV2Pair(addr).swap(amount0Out, amount1Out, receiver, "");
	}

	function _quote(
		address addr,
		uint256 amountIn,
		bytes memory data
	) internal view returns (uint256) {
		console.log("addr: %s", addr);
		(uint112 reserveIn, uint112 reserveOut, ) = IUniswapV2Pair(addr).getReserves();
		console.log("reserveIn: %s, reserveOut: %s", reserveIn, reserveOut);
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
