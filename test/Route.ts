import { BigNumber, BigNumberish } from '@ethersproject/bignumber'
import { ethers } from 'hardhat'
import { toBN } from 'web3-utils'
import { RouteTest } from '../typechain-types'
import { Route } from '../typechain-types/contracts/uroboros/Router'

describe('Route', () => {
	let routeTest: RouteTest

	beforeEach(async () => {
		let RouteTestFactory = await ethers.getContractFactory('RouteTest')
		routeTest = await RouteTestFactory.deploy()
	})

	// it("route: zero length", test1)
	// it("route: insufficient calldata", test2)
	it('route: idk', test3)

	async function test1() {
		let data = Buffer.alloc(32)
		data.writeUint8(0, 31) // explicit
		let route = await routeTest.testDecode(data)
		console.log(route)
	}

	async function test2() {
		let data = Buffer.alloc(64)
		data.writeUint8(1, 31)
		let part: CompiledPart = {
			tokenInPtr: 0,
			tokenOutPtr: 0,
			amountInPtr: 0,
			amountOutMinPtr: 0,
			adaptorId: 0,
			dataStart: 0,
			dataEnd: 0,
			sectionId: 0,
			sectionDepth: 0,
			sectionEnd: 0,
			isInput: false,
			isOutput: false,
		}
		encodePart(part, data, 32)
		let route = await routeTest.testDecode(data)
		console.log(route)
	}

	async function test3() {
		let route: Part[] = [
			{
				tokenIn: '0x0000000000000000000000000000000000000001',
				tokenOut: '0x0000000000000000000000000000000000000002',
				amountIn: '0xde0b6b3a7640000',
				// amountOutMin: '0x1bc16d674ec80000',
				adaptorId: AdaptorId.UniswapV2,
				data: Buffer.alloc(26),
				sectionId: 1,
				sectionDepth: 2,
				sectionEnd: 3,
				isInput: true,
				isOutput: false,
			},
			{
				tokenIn: '0x0000000000000000000000000000000000000002',
				tokenOut: '0x0000000000000000000000000000000000000003',
				// amountIn: '0xde0b6b3a7640000',
				amountOutMin: '0x1bc16d674ec80000',
				adaptorId: AdaptorId.UniswapV2,
				data: Buffer.alloc(26),
				sectionId: 6,
				sectionDepth: 4,
				sectionEnd: 5,
				isInput: false,
				isOutput: true,
			},
		]
		let data = encodeRoute(route)
		let result = await routeTest.testDecode(data)
		verifyDecode(route, result)
	}
})

const enum AdaptorId {
	UniswapV2,
}

type CompiledPart = {
	tokenInPtr: number // 2
	tokenOutPtr: number // 2
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

function encodePart(part: CompiledPart, buf: Buffer, offset: number) {
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
}

type Part = {
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

function encodeRoute(route: Part[]): Buffer {
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
		return {
			tokenInPtr: tokenId.get(part.tokenIn)! * 32 + tokensOffset,
			tokenOutPtr: tokenId.get(part.tokenOut)! * 32 + tokensOffset,
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
	// console.log(compiled)
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

function addId<T>(idMap: Map<T, number>, value: T) {
	if (!idMap.has(value)) {
		idMap.set(value, idMap.size)
	}
}

type ParsedFlags = {
	sectionId: number
	sectionDepth: number
	sectionEnd: number
	isInput: boolean
	isOutput: boolean
}

function parseFlags(_flags: BigNumberish): ParsedFlags {
	let flags = BigNumber.from(_flags)
	return {
		sectionId: flags.and(0xff).toNumber(),
		sectionDepth: flags.shr(8).and(0xff).toNumber(),
		sectionEnd: flags.shr(16).and(0xff).toNumber(),
		isInput: !flags.shr(24).and(0xff).isZero(),
		isOutput: !flags.shr(32).and(0xff).isZero(),
	}
}

function verifyDecode(route: Part[], decoded: Route.PartStructOutput[]) {
	if (route.length !== decoded.length) {
		throw new Error('lengths dont match')
	}
	route.forEach((part, i) => {
		let dec = decoded[i]
		if (part.tokenIn !== dec.tokenIn) throw new Error('tokenIn')
		if (part.tokenOut !== dec.tokenOut) throw new Error('tokenOut')
		if (!BigNumber.from(part.amountIn ?? 0).eq(dec.amountIn)) throw new Error('amountIn')
		if (!BigNumber.from(part.amountOutMin ?? 0).eq(dec.amountOutMin))
			throw new Error('amountOutMin')
		// adaptorId
		let flags = parseFlags(dec._flags)
		if (part.sectionId !== flags.sectionId) throw new Error('sectionId')
		if (part.sectionDepth !== flags.sectionDepth) throw new Error('sectionDepth')
		if (part.sectionEnd !== flags.sectionEnd) throw new Error('sectionEnd')
		if (part.isInput !== flags.isInput) throw new Error('isInput')
		if (part.isOutput !== flags.isOutput) throw new Error('isOutput')
	})
}
