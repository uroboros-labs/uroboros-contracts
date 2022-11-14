import { BigNumber } from "@ethersproject/bignumber"
import { expect } from "chai"
import { ethers } from "hardhat"
import {
	ERC20PresetFixedSupply,
	UniswapV2Adaptor,
	UniswapV2Pair,
	UroborusRouter,
} from "../typechain-types"
import { createUniswapV2Pair, encodeRoute, getZeroForOne } from "./utils"

let deployer: string,
	WETH: ERC20PresetFixedSupply,
	USDC: ERC20PresetFixedSupply,
	URB: ERC20PresetFixedSupply,
	BTC: ERC20PresetFixedSupply,
	wethUsdcPair14: UniswapV2Pair,
	wethUsdcPair15: UniswapV2Pair,
	urbUsdcPair12: UniswapV2Pair,
	btcWethPair17: UniswapV2Pair,
	btcUsdcPair19: UniswapV2Pair,
	urbRouter: UroborusRouter,
	uniswapV2Adaptor: UniswapV2Adaptor

describe("RouteExecutor", () => {
	beforeEach(async () => {
		let [signer] = await ethers.getSigners()
		deployer = signer.address
		console.log("deployer:", deployer)

		let [ERC20PresetFixedSupply, UniswapV2Adaptor, UroborosRouter] = await Promise.all([
			ethers.getContractFactory("ERC20PresetFixedSupply"),
			ethers.getContractFactory("UniswapV2Adaptor"),
			ethers.getContractFactory("UroborusRouter"),
		])

		await signer.sendTransaction({ to: signer.address }) // set nonce=1

		uniswapV2Adaptor = await UniswapV2Adaptor.deploy() // nonce=1
		console.log("uniswapV2Adaptor.address:", uniswapV2Adaptor.address)
		//
		;[WETH, USDC, URB, BTC] = await Promise.all([
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
		])

		urbRouter = await UroborosRouter.deploy()
		;[wethUsdcPair14, wethUsdcPair15, urbUsdcPair12, btcWethPair17, btcUsdcPair19] =
			await Promise.all([
				createUniswapV2Pair(WETH, USDC, "100000000000000000000", "400000000000000000000"),
				createUniswapV2Pair(WETH, USDC, "100000000000000000000", "500000000000000000000"),
				createUniswapV2Pair(URB, USDC, "100000000000000000000", "200000000000000000000"),
				createUniswapV2Pair(BTC, WETH, "100000000000000000000", "700000000000000000000"),
				createUniswapV2Pair(BTC, USDC, "100000000000000000000", "900000000000000000000"),
			])

		await Promise.all([
			WETH.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1)),
			USDC.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1)),
			URB.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1)),
		])
	})

	// it("WETH -> USDC -> URB", async () => {
	// 	let route = encodeRoute([
	// 		{
	// 			amountIn: "10000000000000000",
	// 			tokenIn: WETH.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair14.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(WETH.address, USDC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0, // sectionEnd is used when depth > currentDepth
	// 			isInput: true,
	// 		},
	// 		{
	// 			tokenIn: USDC.address,
	// 			tokenOut: URB.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: urbUsdcPair12.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, URB.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0,
	// 		},
	// 	])
	// 	console.log(route)
	// 	let [amounts, skip] = await urbRouter.callStatic.swap({ ...route, deployer })
	// 	console.log(amounts)
	// 	console.log(skip)
	// 	expect(amounts[0]).eq("39872025157812017")
	// 	expect(amounts[1]).eq("19870261882150628")
	// })

	// it("USDC->WETH->USDC, 41->15", async () => {
	// 	let route = encodeRoute([
	// 		{
	// 			amountIn: "1000000000000000000",
	// 			tokenIn: USDC.address,
	// 			tokenOut: WETH.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair14.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, WETH.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0,
	// 			isInput: true,
	// 		},
	// 		{
	// 			amountOutMin: "1000000000000000000",
	// 			tokenIn: WETH.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair15.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(WETH.address, USDC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0,
	// 		},
	// 	])
	// 	console.log(route)
	// 	let [amounts, skip] = await urbRouter.callStatic.swap({ ...route, deployer })
	// 	console.log(amounts)
	// 	console.log(skip)
	// 	expect(amounts[0]).eq("248605413159054346")
	// 	expect(amounts[1]).eq("1236110171506408603")
	// })

	// it("WETH->USDC,URB->USDC", async () => {
	// 	let route = encodeRoute([
	// 		{
	// 			amountIn: "1000000000000000000",
	// 			tokenIn: WETH.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair14.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(WETH.address, USDC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 1,
	// 			sectionEnd: 1,
	// 			isInput: true,
	// 		},
	// 		{
	// 			amountIn: "1000000000000000",
	// 			// amountOutMin: "1000000000000000000000000000000", // mistically freezes when set
	// 			// need to check nested sections
	// 			tokenIn: URB.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: urbUsdcPair12.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(URB.address, USDC.address),
	// 			},
	// 			sectionId: 1,
	// 			sectionDepth: 1,
	// 			sectionEnd: 2,
	// 			isInput: true,
	// 		},
	// 	])
	// 	console.log(route)
	// 	let [amounts, skip] = await urbRouter.callStatic.swap({ ...route, deployer })
	// 	console.log(amounts)
	// 	console.log(skip)
	// 	expect(amounts[0]).eq("3948239995485009935")
	// 	expect(amounts[1]).eq("1993780124005943")
	// })

	// it("WETH->USDC->URB,USDC->WETH, fork - proper balance use", async () => {
	// 	// this is top level section with split-trade
	// 	let route = encodeRoute([
	// 		{
	// 			amountIn: "1000000000000000000",
	// 			amountOutMin: "1974119997742504967",
	// 			tokenIn: WETH.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair14.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(WETH.address, USDC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 3,
	// 			isInput: true,
	// 		},
	// 		{
	// 			amountIn: "1974119997742504967",
	// 			tokenIn: USDC.address,
	// 			tokenOut: URB.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: urbUsdcPair12.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, URB.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0,
	// 		},
	// 		{
	// 			tokenIn: USDC.address,
	// 			tokenOut: WETH.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair15.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, WETH.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 0,
	// 		},
	// 	])
	// 	console.log(route)

	// 	let [amounts, skip] = await urbRouter.callStatic.swap({ ...route, deployer })
	// 	console.log(amounts)
	// 	console.log(skip)
	// 	expect(amounts[0]).eq("3948239995485009935") // WETH(1) -> USDC(3.9) ~1/4
	// 	expect(amounts[1]).eq("974411898691759675") // USDC(1.9) -> URB(0.9) ~2/1
	// 	expect(amounts[2]).eq("392056908979145419") // USDC(1.9) -> WETH(0.39) ~1/5
	// })

	// and then swap WETH for smth - ...BTC+,WETH->...
	// it("URB->(USDC->WETH->USDC)->BTC, cancelled cycle", async () => {
	// 	let route = encodeRoute([
	// 		{
	// 			isInput: true,
	// 			amountIn: "1000000000000000000",
	// 			tokenIn: URB.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: urbUsdcPair12.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(URB.address, USDC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 4,
	// 		},
	// 		{
	// 			tokenIn: USDC.address,
	// 			tokenOut: WETH.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair14.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, WETH.address),
	// 			},
	// 			sectionId: 1,
	// 			sectionDepth: 1,
	// 			sectionEnd: 3,
	// 		},
	// 		{
	// 			amountOutMin: "2428514733306148413",
	// 			tokenIn: WETH.address,
	// 			tokenOut: USDC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: wethUsdcPair15.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(WETH.address, USDC.address),
	// 			},
	// 			sectionId: 1,
	// 			sectionDepth: 1,
	// 			sectionEnd: 3,
	// 		},
	// 		{
	// 			tokenIn: USDC.address,
	// 			tokenOut: BTC.address,
	// 			swapData: {
	// 				type: "uniswap-v2",
	// 				address: btcUsdcPair19.address,
	// 				swapFee: 30,
	// 				sellFee: 0,
	// 				buyFee: 0,
	// 				zeroForOne: getZeroForOne(USDC.address, BTC.address),
	// 			},
	// 			sectionId: 0,
	// 			sectionDepth: 0,
	// 			sectionEnd: 4,
	// 		},
	// 	])
	// 	console.log(route)

	// 	let [amounts, skip] = await urbRouter.callStatic.swap({ ...route, deployer })
	// 	console.log(amounts)
	// 	console.log(skip)
	// 	expect(skip).eq(2) // section 1 skipped
	// 	expect(amounts[0]).eq("1974119997742504967")
	// 	expect(amounts[1]).eq("489591267126799483")
	// 	expect(amounts[2]).eq("2428514733306148412") // <amountOutMin
	// 	expect(amounts[3]).eq("218189583805294788") // 1974119997742504967->.. ~9/1
	// })

	it("URB->USDC->WETH->USDC->BTC,WETH->BTC", async () => {
		let route = encodeRoute([
			{
				isInput: true,
				amountIn: "1000000000000000000",
				tokenIn: URB.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: urbUsdcPair12.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(URB.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 5,
			},
			{
				tokenIn: USDC.address,
				tokenOut: WETH.address,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair14.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, WETH.address),
				},
				sectionId: 1,
				sectionDepth: 1,
				sectionEnd: 3,
			},
			{
				amountIn: "244795633563399741",
				tokenIn: WETH.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair15.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, USDC.address),
				},
				sectionId: 1,
				sectionDepth: 1,
				sectionEnd: 3,
			},
			{
				tokenIn: USDC.address,
				tokenOut: BTC.address,
				swapData: {
					type: "uniswap-v2",
					address: btcUsdcPair19.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, BTC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 5,
			},
			{
				// amountIn: "244795633563399742",
				tokenIn: WETH.address,
				tokenOut: BTC.address,
				swapData: {
					type: "uniswap-v2",
					address: btcWethPair17.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, BTC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 5,
			},
		])
		let [amounts, skipMask] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log(amounts)
		console.log(skipMask)
		expect(amounts[0]).eq("1974119997742504967") // URB(1) -> USDC(1.9) ~ 1/2
		expect(amounts[1]).eq("489591267126799483") // USDC(1.9) -> WETH(0.48) ~ 4/1
		expect(amounts[2]).eq("1217213387297704158") // WETH(0.24) -> USDC(1.2) ~ 1/5
		expect(amounts[3]).eq("134645131985864165") // USDC(1.2) -> BTC(0.13) ~ 9/1
		// WETH still left, need to swap it to BTC
		expect(amounts[4]).not.eq("0")
	})
})
