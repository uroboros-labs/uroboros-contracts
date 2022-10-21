import { ethers } from "hardhat";
import { expect } from "chai";
import { ERC20PresetFixedSupply, RouteExecutor, UniswapV2Pair } from "../typechain-types";
import { createUniswapV2Pair, encodeUniswapV2Swap } from "./utils";

let WETH: ERC20PresetFixedSupply,
	USDC: ERC20PresetFixedSupply,
	URB: ERC20PresetFixedSupply,
	wethUsdcPair: UniswapV2Pair,
	urbUsdcPair: UniswapV2Pair,
	routeExecutor: RouteExecutor;

async function init() {
	let [signer] = await ethers.getSigners();

	let [ERC20PresetFixedSupply, UniswapV2Factory, UniswapV2Adaptor, RouteExecutor] =
		await Promise.all([
			ethers.getContractFactory("ERC20PresetFixedSupply"),
			ethers.getContractFactory("UniswapV2Factory"),
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

		let route: RouteExecutor.RoutePartStruct[] = [
			{
				tokenIn: WETH.address,
				amountIn: "10000000000000000",
				amountOutMin: 0,
				adaptorId: 0,
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
				tokenIn: USDC.address,
				amountIn: 0,
				amountOutMin: 0,
				adaptorId: 0,
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
		let amounts = await routeExecutor.callStatic.execute(route);
		console.log(amounts);
		expect(amounts[0].eq("39872025157812017")).eq(true);
		expect(amounts[1].eq("19870261882150628")).eq(true);
	});

	it("WETH -> USDC -> URB <amountOutMIn", async () => {
		await initialized;

		let route: RouteExecutor.RoutePartStruct[] = [
			{
				tokenIn: WETH.address,
				amountIn: "10000000000000000",
				amountOutMin: 0,
				adaptorId: 0,
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
				tokenIn: USDC.address,
				amountIn: 0,
				amountOutMin: "19870261882150629",
				adaptorId: 0,
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
		let amounts = await routeExecutor.callStatic.execute(route);
		console.log(amounts);
		expect(amounts[0].isZero()).eq(true);
		expect(amounts[1].isZero()).eq(true);
	});
});
