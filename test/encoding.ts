import { BigNumber, BigNumberish } from '@ethersproject/bignumber'
import { toBN } from 'web3-utils'

export const enum AdaptorId {
	UniswapV2,
}

export type CompiledPart = {
	tokenInPtr: number // 2
	tokenOutPtr: number // 2
	tokenInId: number
	tokenOutId: number
	amountInPtr: number // 2
	amountOutMinPtr: number // 2
	adaptorId: AdaptorId // 1
	dataStart: number // 2
	dataEnd: number // 2
	sectionId: number // 1
	sectionDepth: number // 1
	sectionEnd: number // 1
	isInput: boolean // 1
	isOutput: boolean // 1
}

export type Part = {
	tokenIn: string
	tokenOut: string
	amountIn?: string
	amountOutMin?: string
	adaptorId: AdaptorId
	data: Buffer
	sectionId: number
	sectionDepth: number
	sectionEnd: number
	isInput: boolean
	isOutput: boolean
}

export type ParsedFlags = {
	sectionId: number
	sectionDepth: number
	sectionEnd: number
	isInput: boolean
	isOutput: boolean
}

export function encodePart(part: CompiledPart, buf: Buffer, offset: number) {
	buf.writeUint16BE(part.tokenInPtr, offset + 30)
	buf.writeUint16BE(part.tokenOutPtr, offset + 28)
	buf.writeUint16BE(part.amountInPtr, offset + 26)
	buf.writeUint16BE(part.amountOutMinPtr, offset + 24)
	buf.writeUint8(part.adaptorId, offset + 23)
	buf.writeUint16BE(part.dataStart, offset + 21)
	buf.writeUint16BE(part.dataEnd, offset + 19)
	buf.writeUint8(part.sectionId, offset + 18)
	buf.writeUint8(part.sectionDepth, offset + 17)
	buf.writeUint8(part.sectionEnd, offset + 16)
	buf.writeUint8(part.isInput ? 1 : 0, offset + 15)
	buf.writeUint8(part.isOutput ? 1 : 0, offset + 14)
	buf.writeUint8(part.tokenInId, offset + 13)
	buf.writeUint8(part.tokenOutId, offset + 12)
}

export function encodeRoute(route: Part[]): Buffer {
	let tokenId = new Map<string, number>()
	let amountId = new Map<string, number>()
	// let size = 0
	route.forEach(part => {
		addId(tokenId, part.tokenIn)
		addId(tokenId, part.tokenOut)
		if (part.amountIn) addId(amountId, part.amountIn)
		if (part.amountOutMin) addId(amountId, part.amountOutMin)
	})
	let partsOffset = 32 // route length (header)
	let tokensOffset = partsOffset + route.length * 32
	let amountsOffset = tokensOffset + tokenId.size * 32
	let offset = amountsOffset + amountId.size * 32
	let compiled: CompiledPart[] = route.map(part => {
		let dataStart = offset
		offset += part.data.length
		let dataEnd = offset
		let tokenInId = tokenId.get(part.tokenIn)!
		let tokenOutId = tokenId.get(part.tokenOut)!
		return {
			tokenInPtr: tokenInId * 32 + tokensOffset,
			tokenOutPtr: tokenOutId * 32 + tokensOffset,
			tokenInId,
			tokenOutId,
			amountInPtr: part.amountIn ? amountId.get(part.amountIn)! * 32 + amountsOffset : 0,
			amountOutMinPtr: part.amountOutMin
				? amountId.get(part.amountOutMin)! * 32 + amountsOffset
				: 0,
			adaptorId: part.adaptorId,
			dataStart,
			dataEnd,
			sectionId: part.sectionId,
			sectionDepth: part.sectionDepth,
			sectionEnd: part.sectionEnd,
			isInput: part.isInput,
			isOutput: part.isOutput,
		}
	})
	let data = Buffer.alloc(offset + 32)
	data.writeUInt32BE(route.length, 28) // 32 - 4
	offset = 32
	compiled.forEach(part => {
		encodePart(part, data, offset)
		offset += 32
	})
	tokenId.forEach((_, token) => {
		data.write(token.slice(2), offset + 12, 'hex')
		offset += 32
	})
	amountId.forEach((_, amount) => {
		toBN(amount).toBuffer('be', 32).copy(data, offset)
		offset += 32
	})
	route.forEach(part => {
		part.data.copy(data, offset)
		offset += part.data.length
	})
	return data
}

export function parseFlags(_flags: BigNumberish): ParsedFlags {
	let flags = BigNumber.from(_flags)
	return {
		sectionId: flags.and(0xff).toNumber(),
		sectionDepth: flags.shr(8).and(0xff).toNumber(),
		sectionEnd: flags.shr(16).and(0xff).toNumber(),
		isInput: !flags.shr(24).and(0xff).isZero(),
		isOutput: !flags.shr(32).and(0xff).isZero(),
		// todo: tokenInId, tokenOutId
	}
}

function addId<T>(idMap: Map<T, number>, value: T) {
	if (!idMap.has(value)) {
		idMap.set(value, idMap.size)
	}
}

export type UniswapV2AdaptorData = {
	address: string
	swapFee: number
	sellFee: number
	buyFee: number
	zeroForOne: boolean
}

export function encodeUniswapV2AdaptorData(data: UniswapV2AdaptorData): Buffer {
	let buf = Buffer.alloc(26)
	buf.write(data.address.slice(2), 'hex')
	buf.writeUint8(data.swapFee, 20)
	buf.writeUint16BE(data.sellFee, 21)
	buf.writeUint16BE(data.buyFee, 23)
	buf.writeUint8(data.zeroForOne ? 1 : 0, 25)
	return buf
}
