// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

interface IUniswapV2Callee {
	function uniswapV2Call(
		address sender,
		uint256 amount0,
		uint256 amount1,
		bytes calldata data
	) external;
}
