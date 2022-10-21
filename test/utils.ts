import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { ethers } from "hardhat";
import { encodePacked, padLeft } from "web3-utils";
import { ERC20PresetFixedSupply, UniswapV2Factory, UniswapV2Pair } from "../typechain-types";

export async function createUniswapV2Pair(
	factory: UniswapV2Factory,
	token0: ERC20PresetFixedSupply,
	token1: ERC20PresetFixedSupply,
	reserve0: BigNumberish,
	reserve1: BigNumberish
): Promise<UniswapV2Pair> {
	let pair = await factory
		.createPair(token0.address, token1.address)
		.then((creation) => creation.wait())
		.then((receipt) => {
			// @ts-ignore
			let addr = receipt.events[0].args[2];
			return ethers.getContractAt("UniswapV2Pair", addr);
		});

	await Promise.all([
		token0.transfer(pair.address, reserve0),
		token1.transfer(pair.address, reserve1),
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
