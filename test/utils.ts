import { BigNumber, BigNumberish } from "@ethersproject/bignumber"
import { ethers } from "hardhat"
import { encodePacked, padLeft } from "web3-utils"
import { ERC20PresetFixedSupply, UniswapV2Pair, UroborusRouter } from "../typechain-types"

export async function createUniswapV2Pair(
	token0: ERC20PresetFixedSupply,
	token1: ERC20PresetFixedSupply,
	amount0: BigNumberish,
	amount1: BigNumberish
): Promise<UniswapV2Pair> {
	let factory = await ethers.getContractFactory("UniswapV2Pair")
	let pair = await factory.deploy()
	if (BigNumber.from(token0.address).gt(token1.address)) {
		;[token0, token1] = [token1, token0]
		;[amount0, amount1] = [amount1, amount0]
	}
	await pair.initialize(token0.address, token1.address)
	await Promise.all([
		token0.transfer(pair.address, amount0),
		token1.transfer(pair.address, amount1),
	])
	await pair.sync()
	return pair
}

export type UniswapV2SwapParams = {
	pairAddress: string
	tokenIn: BigNumberish
	tokenOut: BigNumberish
	swapFee: number
	sellFee: number
	buyFee: number
}

export function encodeUniswapV2Swap(p: UniswapV2SwapParams): string | null {
	return encodePacked(
		BigNumber.from(p.tokenIn).gt(p.tokenOut) ? "0x01" : "0x00",
		padLeft(p.swapFee, 2),
		padLeft(p.sellFee, 4),
		padLeft(p.buyFee, 4),
		p.pairAddress
	)
}

export type SwapPart = {
	amountInIdx: number
	amountOutMinIdx: number
	tokenInIdx: number
	tokenOutIdx: number
	adaptorId: number
	dataStart: number
	dataEnd: number
	sectionId: number
	sectionDepth: number
	sectionEnd: number
}

export function encodeSwapPart(pt: SwapPart): string {
	// amountInIdx
	// amountOutMinIdx
	// tokenInIdx
	// tokenOutIdx
	// adaptorId
	// dataStart
	// dataEnd
	// sectionId
	// sectionDepth
	// sectionEnd
	// console.log([
	// 	padLeft(pt.sectionEnd, 2),
	// 	padLeft(pt.sectionDepth, 2),
	// 	padLeft(pt.sectionId, 2),
	// 	padLeft(pt.dataEnd, 4),
	// 	padLeft(pt.dataStart, 4),
	// 	padLeft(pt.adaptorId, 2),
	// 	padLeft(pt.tokenOutIdx, 2),
	// 	padLeft(pt.tokenInIdx, 2),
	// 	padLeft(pt.amountOutMinIdx, 2),
	// 	padLeft(pt.amountInIdx, 2),
	// ])
	return padLeft(
		encodePacked(
			padLeft(pt.sectionEnd, 2),
			padLeft(pt.sectionDepth, 2),
			padLeft(pt.sectionId, 2),
			padLeft(pt.dataEnd, 4),
			padLeft(pt.dataStart, 4),
			padLeft(pt.adaptorId, 2),
			padLeft(pt.tokenOutIdx, 2),
			padLeft(pt.tokenInIdx, 2),
			padLeft(pt.amountOutMinIdx, 2),
			padLeft(pt.amountInIdx, 2)
		)!,
		64
	)
}

export type UniswapV2SwapData = {
	address: BigNumberish
	zeroForOne: boolean
	swapFee: number
	sellFee: number
	buyFee: number
}

export type SwapData =
	| ({
			type: "uniswap-v2"
	  } & UniswapV2SwapData)
	| {
			type: "uniswap-v3"
	  }

export type RoutePart = {
	amountIn?: BigNumberish
	amountOutMin?: BigNumberish
	tokenIn: string
	tokenOut: string
	swapData: SwapData
	sectionId: number
	sectionDepth: number
	sectionEnd: number
}

export type EncodedRoute = {
	parts: BigNumberish[]
	amounts: BigNumberish[]
	tokens: string[]
	data: string
}

class IndexMap<T> extends Map<T, number> {
	add(item: T): number {
		let idx = this.get(item)
		if (idx !== undefined) {
			return idx
		}
		idx = this.size
		this.set(item, idx)
		return idx
	}

	items(): T[] {
		return [...this.keys()]
	}
}

export type AdaptorIdAndSwapData = {
	adaptorId: number
	swapData: string
}

export function encodeUniswapV2SwapData(data: UniswapV2SwapData): string {
	return encodePacked(
		padLeft(data.address.toString(), 40),
		padLeft(data.swapFee, 2),
		padLeft(data.sellFee, 4),
		padLeft(data.buyFee, 4),
		data.zeroForOne ? "0x01" : "0x00"
	)!
}

export function encodeAdaptorIdAndSwapData(swapData: SwapData): AdaptorIdAndSwapData {
	switch (swapData.type) {
		case "uniswap-v2":
			return { adaptorId: 1, swapData: encodeUniswapV2SwapData(swapData) }
		default:
			throw new Error("type not implemented")
	}
}

export function encodeRoute(routeParts: RoutePart[]): EncodedRoute {
	let tokens = new IndexMap<string>()
	let amounts = new IndexMap<BigNumberish>()
	routeParts.forEach(pt => {
		tokens.add(pt.tokenIn)
		tokens.add(pt.tokenOut)
		if (pt.amountIn !== undefined) {
			amounts.add(pt.amountIn)
		}
		if (pt.amountOutMin !== undefined) {
			amounts.add(pt.amountOutMin)
		}
	})
	let data = "0x"
	let parts = routeParts.map(pt => {
		let { adaptorId, swapData } = encodeAdaptorIdAndSwapData(pt.swapData)
		let dataStart = (data.length - 0x2) / 0x2
		data = encodePacked(data, swapData)!
		let dataEnd = (data.length - 0x2) / 0x2
		return encodeSwapPart({
			// @ts-ignore
			amountInIdx: pt.amountIn ? amounts.get(pt.amountIn) : amounts.size,
			// @ts-ignore
			amountOutMinIdx: pt.amountOutMin ? amounts.get(pt.amountOutMin) : amounts.size,
			tokenInIdx: tokens.get(pt.tokenIn)!,
			tokenOutIdx: tokens.get(pt.tokenOut)!,
			adaptorId,
			dataStart,
			dataEnd,
			sectionId: pt.sectionId,
			sectionDepth: pt.sectionDepth,
			sectionEnd: pt.sectionEnd,
		})
	})
	return {
		parts,
		tokens: tokens.items(),
		amounts: amounts.items(),
		data,
	}
}
