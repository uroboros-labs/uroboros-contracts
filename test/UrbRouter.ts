import { BigNumber } from "@ethersproject/bignumber"
import { expect } from "chai"
import { ethers } from "hardhat"
import {
	ERC20PresetFixedSupply,
	ERC20TransferFee,
	UniswapV2Adaptor,
	UniswapV2Pair,
	UrbRouter,
} from "../typechain-types"
import { createUniswapV2Pair, encodeRoute, getZeroForOne } from "./utils"

let deployer: string,
	WETH: ERC20PresetFixedSupply,
	USDC: ERC20PresetFixedSupply,
	URB: ERC20PresetFixedSupply,
	BTC: ERC20PresetFixedSupply,
	SFM: ERC20TransferFee,
	wethUsdcPair14: UniswapV2Pair,
	wethUsdcPair15: UniswapV2Pair,
	urbUsdcPair12: UniswapV2Pair,
	btcWethPair17: UniswapV2Pair,
	btcUsdcPair19: UniswapV2Pair,
	usdcSfmPair16: UniswapV2Pair,
	urbSfmPair14: UniswapV2Pair,
	urbRouter: UrbRouter,
	uniswapV2Adaptor: UniswapV2Adaptor

describe("RouteExecutor", () => {
	beforeEach(async () => {
		let [signer] = await ethers.getSigners()
		deployer = signer.address
		// console.log("deployer:", deployer)

		let [ERC20PresetFixedSupply, UniswapV2Adaptor, UrbRouter, ERC20TransferFee] = await Promise.all([
			ethers.getContractFactory("ERC20PresetFixedSupply"),
			ethers.getContractFactory("UniswapV2Adaptor"),
			ethers.getContractFactory("UrbRouter"),
			ethers.getContractFactory("ERC20TransferFee"),
		])

		await signer.sendTransaction({ to: signer.address }) // set nonce=1

		uniswapV2Adaptor = await UniswapV2Adaptor.deploy() // nonce=1

		WETH = await ERC20PresetFixedSupply.deploy("Wrapped Ether", "WETH", "100000000000000000000000", signer.address)
		USDC = await ERC20PresetFixedSupply.deploy("USDC", "USDC", "100000000000000000000000", signer.address)
		URB = await ERC20PresetFixedSupply.deploy("Uroboros", "URB", "100000000000000000000000", signer.address)
		BTC = await ERC20PresetFixedSupply.deploy("Pegged Bitcoin", "BTC", "100000000000000000000000", signer.address)
		SFM = await ERC20TransferFee.deploy("SAFEMOON", "SFM", "100000000000000000000000")

		urbRouter = await UrbRouter.deploy()

		wethUsdcPair14 = await createUniswapV2Pair(WETH, USDC, "100000000000000000000", "400000000000000000000")
		wethUsdcPair15 = await createUniswapV2Pair(WETH, USDC, "100000000000000000000", "500000000000000000000")
		urbUsdcPair12 = await createUniswapV2Pair(URB, USDC, "100000000000000000000", "200000000000000000000")
		btcWethPair17 = await createUniswapV2Pair(BTC, WETH, "100000000000000000000", "700000000000000000000")
		btcUsdcPair19 = await createUniswapV2Pair(BTC, USDC, "100000000000000000000", "900000000000000000000")
		usdcSfmPair16 = await createUniswapV2Pair(USDC, SFM, "100000000000000000000", "600000000000000000000")
		urbSfmPair14 = await createUniswapV2Pair(URB, SFM, "100000000000000000000", "400000000000000000000")

		await SFM.setTransferToFee(usdcSfmPair16.address, "3000")
		await SFM.setTransferFromFee(usdcSfmPair16.address, "2000")
		await SFM.setTransferToFee(urbSfmPair14.address, "3000")
		await SFM.setTransferFromFee(urbSfmPair14.address, "2000")

		await WETH.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1))
		await USDC.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1))
		await URB.approve(urbRouter.address, BigNumber.from(1).shl(256).sub(1))
	})

	it("URB->SFM->USDC", async () => {
		let route = encodeRoute([
			{
				isInput: true,
				amountIn: "1000000000000000000",
				tokenIn: URB.address,
				tokenOut: SFM.address,
				swapData: {
					type: "uniswap-v2",
					address: urbSfmPair14.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 2000,
					zeroForOne: getZeroForOne(URB.address, SFM.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 2,
			},
			{
				tokenIn: SFM.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: usdcSfmPair16.address,
					swapFee: 30,
					sellFee: 3000,
					buyFee: 0,
					zeroForOne: getZeroForOne(SFM.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 2,
			},
		])
		// console.log(route)
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		// console.log("amounts:", amounts)
		// console.log("skipMask:", skipMask)
		// console.log("gasUsed:", gasUsed)
		expect(skipMask).eq("0")
		expect(amounts[0]).eq("3157881352671220601") // URB(1.0) -> SFM(3.15) ~ 1/4 + 20%
		expect(amounts[1]).eq("365954187525228600") //
	})

	it("USDC->SFM, invalid quote fee", async () => {
		let route = encodeRoute([
			{
				isInput: true,
				amountIn: "10000000000000000",
				amountOutMin: "47835665340662189",
				tokenIn: USDC.address,
				tokenOut: SFM.address,
				swapData: {
					type: "uniswap-v2",
					address: usdcSfmPair16.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, SFM.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 1,
				isOutput: true,
			},
		])
		console.log(route)
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("47835665340662188")
	})

	it("WETH->USDC->URB", async () => {
		let route = encodeRoute([
			{
				amountIn: "10000000000000000",
				tokenIn: WETH.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair14.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0, // sectionEnd is used when depth > currentDepth
				isInput: true,
			},
			{
				tokenIn: USDC.address,
				tokenOut: URB.address,
				swapData: {
					type: "uniswap-v2",
					address: urbUsdcPair12.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, URB.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0,
				isOutput: true,
			},
		])
		console.log(route)
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("39872025157812017")
		expect(amounts[1]).eq("19870261882150628")
	})

	it("USDC->WETH->USDC, 41->15", async () => {
		let route = encodeRoute([
			{
				amountIn: "1000000000000000000",
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
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0,
				isInput: true,
			},
			{
				amountOutMin: "1000000000000000000",
				tokenIn: WETH.address,
				tokenOut: USDC.address,
				isOutput: true,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair15.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0,
			},
		])
		console.log(route)
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("248605413159054346")
		expect(amounts[1]).eq("1236110171506408603")
	})

	it("WETH->USDC,URB->USDC", async () => {
		let route = encodeRoute([
			{
				amountIn: "1000000000000000000",
				tokenIn: WETH.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair14.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 1,
				sectionEnd: 1,
				isInput: true,
				isOutput: true,
			},
			{
				amountIn: "1000000000000000",
				// amountOutMin: "1000000000000000000000000000000", // mistically freezes when set
				// need to check nested sections
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
				sectionId: 1,
				sectionDepth: 1,
				sectionEnd: 2,
				isInput: true,
				isOutput: true,
			},
		])
		console.log(route)
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("3948239995485009935")
		expect(amounts[1]).eq("1993780124005943")
	})

	it("WETH->USDC->URB,USDC->WETH, fork - proper balance use", async () => {
		// this is top level section with split-trade
		let route = encodeRoute([
			{
				amountIn: "1000000000000000000",
				amountOutMin: "1974119997742504967",
				tokenIn: WETH.address,
				tokenOut: USDC.address,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair14.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(WETH.address, USDC.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 3,
				isInput: true,
			},
			{
				amountIn: "1974119997742504967",
				tokenIn: USDC.address,
				tokenOut: URB.address,
				isOutput: true,
				swapData: {
					type: "uniswap-v2",
					address: urbUsdcPair12.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, URB.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0,
			},
			{
				tokenIn: USDC.address,
				tokenOut: WETH.address,
				isOutput: true,
				swapData: {
					type: "uniswap-v2",
					address: wethUsdcPair15.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: getZeroForOne(USDC.address, WETH.address),
				},
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 0,
			},
		])
		console.log(route)

		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("3948239995485009935") // WETH(1) -> USDC(3.9) ~1/4
		expect(amounts[1]).eq("974411898691759675") // USDC(1.9) -> URB(0.9) ~2/1
		expect(amounts[2]).eq("392056908979145419") // USDC(1.9) -> WETH(0.39) ~1/5
	})

	// and then swap WETH for smth - ...BTC+,WETH->...
	it("URB->(USDC->WETH->USDC)->BTC, cancelled cycle", async () => {
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
				sectionEnd: 4,
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
				amountOutMin: "2428514733306148413",
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
				isOutput: true,
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
				sectionEnd: 4,
			},
		])
		console.log(route)

		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(skipMask).eq(2) // section 1 skipped
		expect(amounts[0]).eq("1974119997742504967")
		expect(amounts[1]).eq("489591267126799483")
		expect(amounts[2]).eq("2428514733306148412") // <amountOutMin
		expect(amounts[3]).eq("218189583805294788") // 1974119997742504967->.. ~9/1
	})

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
				isOutput: true,
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
				isOutput: true,
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
		let [amounts, skipMask, gasUsed] = await urbRouter.callStatic.swap({ ...route, deployer })
		console.log("amounts:", amounts)
		console.log("skipMask:", skipMask)
		console.log("gasUsed:", gasUsed)
		expect(amounts[0]).eq("1974119997742504967") // URB(1) -> USDC(1.9) ~ 1/2
		expect(amounts[1]).eq("489591267126799483") // USDC(1.9) -> WETH(0.48) ~ 4/1
		expect(amounts[2]).eq("1217213387297704158") // WETH(0.24) -> USDC(1.2) ~ 1/5
		expect(amounts[3]).eq("134645131985864165") // USDC(1.2) -> BTC(0.13) ~ 9/1
		// WETH still left, need to swap it to BTC
		// expect(amounts[4]).not.eq("0")
		expect(amounts[4]).eq("34850245669499310") // WETH(0.24) -> BTC(0.03) ~ 7/1
	})
})
