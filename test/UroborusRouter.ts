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
	BTC: ERC20PresetFixedSupply,
	wethUsdcPair14: UniswapV2Pair,
	wethUsdcPair15: UniswapV2Pair,
	urbUsdcPair12: UniswapV2Pair,
	btcWethPair17: UniswapV2Pair,
	uroborosRouter: UroborusRouter,
	uniswapV2Adaptor: UniswapV2Adaptor;

async function init() {
	let [signer] = await ethers.getSigners();

	let [ERC20PresetFixedSupply, UniswapV2Adaptor, UroborosRouter] = await Promise.all([
		ethers.getContractFactory("ERC20PresetFixedSupply"),
		ethers.getContractFactory("UniswapV2Adaptor"),
		ethers.getContractFactory("UroborusRouter"),
	]);

	uniswapV2Adaptor = await UniswapV2Adaptor.deploy();

	[WETH, USDC, URB, BTC] = await Promise.all([
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
		ERC20PresetFixedSupply.deploy(
			"Pegged Bitcoin",
			"BTC",
			"100000000000000000000000",
			signer.address
		),
	]);

	uroborosRouter = await UroborosRouter.deploy(signer.address);

	[wethUsdcPair14, wethUsdcPair15, urbUsdcPair12, btcWethPair17] = await Promise.all([
		createUniswapV2Pair(WETH, USDC, "100000000000000000000", "400000000000000000000"),
		createUniswapV2Pair(WETH, USDC, "100000000000000000000", "500000000000000000000"),
		createUniswapV2Pair(URB, USDC, "100000000000000000000", "200000000000000000000"),
		createUniswapV2Pair(BTC, WETH, "100000000000000000000", "700000000000000000000"),
	]);

	await WETH.approve(uroborosRouter.address, "1000000000000000000");
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
					pairAddress: wethUsdcPair14.address,
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
					pairAddress: urbUsdcPair12.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];
		let amounts = await uroborosRouter.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].toString()).eq("39872025157812017");
		expect(amounts[1].toString()).eq("19870261882150628");
	});

	it("USDC->WETH->USDC, 41->15", async () => {
		await initialized;

		let tokens = [USDC.address, WETH.address];
		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "1000000000000000000",
				amountOutMin: 0,
				sectionId: 0,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair14.address,
					tokenIn: USDC.address,
					tokenOut: WETH.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: 0,
				amountOutMin: "1000000000000000000",
				sectionId: 0,
				tokenInId: 1,
				tokenOutId: 0,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair15.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];
		let amounts = await uroborosRouter.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].toString()).eq("248605413159054346");
		expect(amounts[1].toString()).eq("1236110171506408603");
	});

	it("WETH->USDC,URB->USDC", async () => {
		await initialized;

		let tokens = [WETH.address, URB.address, USDC.address];
		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "1000000000000000000",
				amountOutMin: 0,
				sectionId: 1,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair14.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: "1000000000000000",
				amountOutMin: 0,
				sectionId: 2,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair12.address,
					tokenIn: URB.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];

		let amounts = await uroborosRouter.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].toString()).eq("3948239995485009935");
		expect(amounts[1].toString()).eq("1993780124005943");
	});

	it("WETH->USDC->URB,USDC->WETH, fork - proper balance use", async () => {
		await initialized;

		let tokens = [WETH.address, USDC.address, URB.address];
		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "1000000000000000000",
				amountOutMin: "1974119997742504967",
				sectionId: 1,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair14.address,
					tokenIn: WETH.address,
					tokenOut: USDC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: "1974119997742504967",
				amountOutMin: 0,
				sectionId: 1,
				tokenInId: 1,
				tokenOutId: 2,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair12.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: 0,
				amountOutMin: 0,
				sectionId: 1,
				tokenInId: 1,
				tokenOutId: 0,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: wethUsdcPair15.address,
					tokenIn: USDC.address,
					tokenOut: WETH.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];

		let amounts = await uroborosRouter.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].toString()).eq("3948239995485009935"); // WETH(1) -> USDC(3.9) ~1/4
		expect(amounts[1].toString()).eq("974411898691759675"); // USDC(1.9) -> URB(0.9) ~2/1
		expect(amounts[2].toString()).eq("392056908979145419"); // USDC(1.9) -> WETH(0.39) ~1/5
	});

	// in that case two NFT's should be minted
	it("USDC->URB,WETH->BTC, two independent routes", async () => {
		await initialized;

		let tokens = [USDC.address, URB.address, WETH.address, BTC.address];
		let route: UroborusRouter.PartStruct[] = [
			{
				amountIn: "1000000000000000000",
				amountOutMin: 0,
				sectionId: 1,
				tokenInId: 0,
				tokenOutId: 1,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: urbUsdcPair12.address,
					tokenIn: USDC.address,
					tokenOut: URB.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
			{
				amountIn: "1000000000000000000",
				amountOutMin: 0,
				sectionId: 2,
				tokenInId: 2,
				tokenOutId: 3,
				adaptor: uniswapV2Adaptor.address,
				data: encodeUniswapV2Swap({
					pairAddress: btcWethPair17.address,
					tokenIn: WETH.address,
					tokenOut: BTC.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
				})!,
			},
		];

		let amounts = await uroborosRouter.callStatic.executeRoute(route, tokens);
		console.log(amounts);
		expect(amounts[0].toString()).eq("495977798662566437"); // ~2/1
		expect(amounts[1].toString()).eq("142211755857978829"); // ~7/1
	});
});
