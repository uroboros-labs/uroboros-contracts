import { ethers } from "hardhat";
import { encodePacked, padLeft } from "web3-utils";
import { BigNumberish, BigNumber } from "@ethersproject/bignumber";
import {
	ERC20PresetFixedSupply,
	RouteExecutor,
	UniswapV2Factory,
	UniswapV2Pair,
} from "../typechain-types";

let WETH: ERC20PresetFixedSupply,
	USDC: ERC20PresetFixedSupply,
	URB: ERC20PresetFixedSupply,
	wethUsdcPair: UniswapV2Pair,
	urbUsdcPair: UniswapV2Pair,
	routeExecutor: RouteExecutor;

async function createUniswapV2Pair(
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

async function init() {
	let [signer] = await ethers.getSigners();

	let [ERC20PresetFixedSupply, UniswapV2Factory, UniswapV2Pair, UniswapV2Adaptor, RouteExecutor] =
		await Promise.all([
			ethers.getContractFactory("ERC20PresetFixedSupply"),
			ethers.getContractFactory("UniswapV2Factory"),
			ethers.getContractFactory("UniswapV2Pair"),
			ethers.getContractFactory("UniswapV2Adaptor"),
			ethers.getContractFactory("RouteExecutor"),
		]);

	await UniswapV2Adaptor.deploy();

	[WETH, USDC, URB] = await Promise.all([
		ERC20PresetFixedSupply.deploy(
			"Wrapped Ether",
			"WETH",
			"100000000000000000000000",
			signer.address
		),
		ERC20PresetFixedSupply.deploy(
			//
			"USDC",
			"USDC",
			"100000000000000000000000",
			signer.address
		),
		ERC20PresetFixedSupply.deploy(
			"Uroboros",
			"URB",
			"100000000000000000000000",
			signer.address
		),
	]);

	let zero = "0x0000000000000000000000000000000000000000";
	let uniswapV2Factory = await UniswapV2Factory.deploy(zero);
	routeExecutor = await RouteExecutor.deploy(signer.address);

	[wethUsdcPair, urbUsdcPair] = await Promise.all([
		// WETH:USDC = 1:10
		createUniswapV2Pair(
			uniswapV2Factory,
			WETH,
			USDC,
			"100000000000000000000",
			"1000000000000000000000"
		),

		// URB:USDC = 1:2
		createUniswapV2Pair(
			uniswapV2Factory,
			URB,
			USDC,
			"100000000000000000000",
			"200000000000000000000"
		),
	]);

	await WETH.approve(routeExecutor.address, "1000000000000000000");
}

type UniswapV2SwapParams = {
	pairAddress: string;
	tokenIn: BigNumberish;
	tokenOut: BigNumberish;
	swapFee: number;
	sellFee: number;
	buyFee: number;
};

function encodeUniswapV2Swap(p: UniswapV2SwapParams): string | null {
	return encodePacked(
		BigNumber.from(p.tokenIn).lt(p.tokenOut) ? "0x01" : "0x00",
		padLeft(p.swapFee, 2),
		padLeft(p.sellFee, 4),
		padLeft(p.buyFee, 4),
		p.pairAddress
	);
}

describe("RouteExecutor", () => {
	let initialized = init();

	it("works", async () => {
		await initialized;

		let route: RouteExecutor.RoutePartStruct[] = [
			{
				tokenIn: WETH.address,
				amountIn: "1000000000000000000",
				amountOutMin: 0,
				adaptorId: 0,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 25,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				tokenIn: USDC.address,
				amountIn: 0,
				amountOutMin: 0,
				adaptorId: 0,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 25,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];
		let amounts = await routeExecutor.callStatic.execute(route);
		console.log(amounts);
	});
});
