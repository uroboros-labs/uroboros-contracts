import { ethers } from "hardhat";
import { expect } from "chai";
import {
	ERC20PresetFixedSupply,
	UniswapV2Adaptor,
	UniswapV2Pair,
	UroborusRouter,
} from "../typechain-types";
import { createUniswapV2Pair, encodeUniswapV2Swap } from "./utils";

let WETH: ERC20PresetFixedSupply,
	USDC: ERC20PresetFixedSupply,
	URB: ERC20PresetFixedSupply,
	wethUsdcPair: UniswapV2Pair,
	urbUsdcPair: UniswapV2Pair,
	routeExecutor: UroborusRouter,
	uniswapV2Adaptor: UniswapV2Adaptor;

async function init() {
	let [signer] = await ethers.getSigners();

	let [ERC20PresetFixedSupply, UniswapV2Factory, UniswapV2Adaptor, RouteExecutor] =
		await Promise.all([
			ethers.getContractFactory("ERC20PresetFixedSupply"),
			ethers.getContractFactory("UniswapV2Factory"),
			ethers.getContractFactory("UniswapV2Adaptor"),
			ethers.getContractFactory("UroborusRouter"),
		]);

	uniswapV2Adaptor = await UniswapV2Adaptor.deploy();

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
		// WETH:USDC = 1:4
		createUniswapV2Pair(
			uniswapV2Factory,
			WETH,
			USDC,
			"100000000000000000000",
			"400000000000000000000"
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

describe("RouteExecutor", () => {
	let initialized = init();

	it("WETH -> USDC -> URB", async () => {
		await initialized;

		let tokens: string[] = [WETH.address, USDC.address, URB.address];

		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "10000000000000000",
				amountOutMin: 0,
				sectionId: 0,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: 0,
				amountOutMin: 0,
				sectionId: 0,
				tokenInId: 1,
				tokenOutId: 2,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];
		let amounts = await routeExecutor.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].eq("39872025157812017")).eq(true);
		expect(amounts[1].eq("19870261882150628")).eq(true);
	});

	it("WETH -> USDC -> URB <amountOutMIn", async () => {
		await initialized;

		let tokens: string[] = [WETH.address, USDC.address, URB.address];

		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "10000000000000000",
				amountOutMin: 0,
				sectionId: 0,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: 0,
				amountOutMin: "19870261882150629",
				sectionId: 0,
				tokenInId: 1,
				tokenOutId: 2,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];
		let amounts = await routeExecutor.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].isZero()).eq(true);
		expect(amounts[1].isZero()).eq(true);
	});
});
