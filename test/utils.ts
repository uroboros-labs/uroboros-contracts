// import { BigNumber, BigNumberish } from "@ethersproject/bignumber"
// import { ethers } from "hardhat"
// import { encodePacked, padLeft } from "web3-utils"
// import { UniswapV2Pair } from "../typechain-types"
// import { PromiseOrValue } from "../typechain-types/common"

// interface ERC20Like {
// 	address: string
// 	transfer(to: PromiseOrValue<string>, amount: PromiseOrValue<BigNumberish>): Promise<any>
// }

// export async function createUniswapV2Pair(
// 	token0: ERC20Like,
// 	token1: ERC20Like,
// 	amount0: BigNumberish,
// 	amount1: BigNumberish
// ): Promise<UniswapV2Pair> {
// 	let factory = await ethers.getContractFactory("UniswapV2Pair")
// 	let pair = await factory.deploy()
// 	if (BigNumber.from(token0.address).gt(token1.address)) {
// 		;[token0, token1] = [token1, token0]
// 		;[amount0, amount1] = [amount1, amount0]
// 	}
// 	await pair.initialize(token0.address, token1.address)
// 	await Promise.all([
// 		token0.transfer(pair.address, amount0),
// 		token1.transfer(pair.address, amount1),
// 	])
// 	await pair.sync()
// 	return pair
// }

// export type SwapPart = {
// 	amountInPtr: number
// 	amountOutMinPtr: number
// 	tokenInId: number
// 	tokenOutId: number
// 	adaptorId: number
// 	dataStart: number
// 	dataEnd: number
// 	sectionId: number
// 	sectionDepth: number
// 	sectionEnd: number
// 	isInput?: boolean
// 	isOutput?: boolean
// }

// export function encodeSwapPart(pt: SwapPart): string {
// 	return padLeft(
// 		encodePacked(
// 			pt.isOutput ? "0x01" : "0x00",
// 			pt.isInput ? "0x01" : "0x00",
// 			padLeft(pt.sectionEnd, 2),
// 			padLeft(pt.sectionDepth, 2),
// 			padLeft(pt.sectionId, 2),
// 			padLeft(pt.dataEnd, 4),
// 			padLeft(pt.dataStart, 4),
// 			padLeft(pt.adaptorId, 2),
// 			padLeft(pt.tokenOutId, 2),
// 			padLeft(pt.tokenInId, 2),
// 			padLeft(pt.amountOutMinPtr, 4),
// 			padLeft(pt.amountInPtr, 4)
// 		)!,
// 		64
// 	)
// }

// export type UniswapV2SwapData = {
// 	address: BigNumberish
// 	zeroForOne: boolean
// 	swapFee: number
// 	sellFee: number
// 	buyFee: number
// }

// export type SwapData =
// 	| ({
// 			type: "uniswap-v2"
// 	  } & UniswapV2SwapData)
// 	| {
// 			type: "uniswap-v3"
// 	  }

// export type RoutePart = {
// 	amountIn?: BigNumberish
// 	amountOutMin?: BigNumberish
// 	tokenIn: string
// 	tokenOut: string
// 	swapData: SwapData
// 	sectionId: number
// 	sectionDepth: number
// 	sectionEnd: number
// 	isInput?: boolean
// 	isOutput?: boolean
// }

// export type EncodedRoute = {
// 	parts: BigNumberish[]
// 	data: string
// }

// class IndexMap<T> extends Map<T, number> {
// 	add(item: T): number {
// 		let idx = this.get(item)
// 		if (idx !== undefined) {
// 			return idx
// 		}
// 		idx = this.size
// 		this.set(item, idx)
// 		return idx
// 	}

// 	items(): T[] {
// 		return [...this.keys()]
// 	}
// }

// export type AdaptorIdAndSwapData = {
// 	adaptorId: number
// 	swapData: string
// }

// export function encodeUniswapV2SwapData(data: UniswapV2SwapData): string {
// 	return encodePacked(
// 		padLeft(data.address.toString(), 40),
// 		padLeft(data.swapFee, 2),
// 		padLeft(data.sellFee, 4),
// 		padLeft(data.buyFee, 4),
// 		data.zeroForOne ? "0x01" : "0x00"
// 	)!
// }

// export function getZeroForOne(tokenIn: BigNumberish, tokenOut: BigNumberish): boolean {
// 	return BigNumber.from(tokenIn).lt(tokenOut)
// }

// export function encodeAdaptorIdAndSwapData(swapData: SwapData): AdaptorIdAndSwapData {
// 	switch (swapData.type) {
// 		case "uniswap-v2":
// 			return { adaptorId: 1, swapData: encodeUniswapV2SwapData(swapData) }
// 		default:
// 			throw new Error("type not implemented")
// 	}
// }

// export function encodeRoute(routeParts: RoutePart[]): EncodedRoute {
// 	let tokens = new IndexMap<string>()
// 	let amounts = new IndexMap<BigNumberish>()

// 	routeParts.forEach(pt => {
// 		tokens.add(pt.tokenIn)
// 		tokens.add(pt.tokenOut)
// 		if (pt.amountIn !== undefined) {
// 			amounts.add(pt.amountIn)
// 		}
// 		if (pt.amountOutMin !== undefined) {
// 			amounts.add(pt.amountOutMin)
// 		}
// 	})

// 	let data = "0x"

// 	tokens.forEach((_, token) => (data = encodePacked(data, token)!))
// 	// console.log(tokens, data)
// 	amounts.forEach(
// 		(_, amount) => (data = encodePacked(data, padLeft(BigNumber.from(amount)._hex, 64))!)
// 	)
// 	// console.log(amounts, data)

// 	let parts = routeParts.map(pt => {
// 		let { adaptorId, swapData } = encodeAdaptorIdAndSwapData(pt.swapData)
// 		let dataStart = (data.length - 0x2) / 0x2
// 		data = encodePacked(data, swapData)!
// 		let dataEnd = (data.length - 0x2) / 0x2
// 		return encodeSwapPart({
// 			amountInPtr: pt.amountIn ? amounts.get(pt.amountIn)! * 32 + tokens.size * 20 : 0,
// 			amountOutMinPtr: pt.amountOutMin
// 				? amounts.get(pt.amountOutMin)! * 32 + tokens.size * 20
// 				: 0,
// 			tokenInId: tokens.get(pt.tokenIn)!,
// 			tokenOutId: tokens.get(pt.tokenOut)!,
// 			adaptorId,
// 			dataStart,
// 			dataEnd,
// 			sectionId: pt.sectionId,
// 			sectionDepth: pt.sectionDepth,
// 			sectionEnd: pt.sectionEnd,
// 			isInput: pt.isInput,
// 			isOutput: pt.isOutput,
// 		})
// 	})

// 	return {
// 		parts,
// 		// tokens: tokens.items(),
// 		// amounts: amounts.items(),
// 		data,
// 	}
// }
