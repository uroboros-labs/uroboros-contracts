import { BigNumber } from '@ethersproject/bignumber'
import { ethers } from 'hardhat'
import { RouteTest } from '../typechain-types'
import { Route } from '../typechain-types/contracts/uroboros/Router'
import { AdaptorId, CompiledPart, encodePart, encodeRoute, parseFlags, Part } from './encoding'

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
