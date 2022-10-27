import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { ethers } from "hardhat";
import { encodePacked, padLeft } from "web3-utils";
import { ERC20PresetFixedSupply, UniswapV2Pair, UroborusRouter } from "../typechain-types";

export async function createUniswapV2Pair(
	token0: ERC20PresetFixedSupply,
	token1: ERC20PresetFixedSupply,
	amount0: BigNumberish,
	amount1: BigNumberish
): Promise<UniswapV2Pair> {
	let factory = await ethers.getContractFactory("UniswapV2Pair");
	let pair = await factory.deploy();
	if (BigNumber.from(token0.address).gt(token1.address)) {
		[token0, token1] = [token1, token0];
		[amount0, amount1] = [amount1, amount0];
	}
	await pair.initialize(token0.address, token1.address);
	await Promise.all([
		token0.transfer(pair.address, amount0),
		token1.transfer(pair.address, amount1),
	]);
	await pair.sync();
	return pair;
}

export type UniswapV2SwapParams = {
	pairAddress: string;
	tokenIn: BigNumberish;
	tokenOut: BigNumberish;
	swapFee: number;
	sellFee: number;
	buyFee: number;
};

export function encodeUniswapV2Swap(p: UniswapV2SwapParams): string | null {
	return encodePacked(
		BigNumber.from(p.tokenIn).gt(p.tokenOut) ? "0x01" : "0x00",
		padLeft(p.swapFee, 2),
		padLeft(p.sellFee, 4),
		padLeft(p.buyFee, 4),
		p.pairAddress
	);
}
