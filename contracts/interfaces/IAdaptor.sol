// SPDX-License-Identifier: No license
pragma solidity >=0.8.15;

interface IAdaptor {
	function quote(
		address tokenIn,
		uint256 amountIn,
		bytes memory data
	) external view returns (uint256);

	function swap(
		address tokenIn,
		uint256 amountIn,
		bytes memory data,
		address receiver
	) external payable;
}