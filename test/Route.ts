import { ethers } from "hardhat"
import { RouteTest } from "../typechain-types"

describe("Route", () => {
	let routeTest: RouteTest

	beforeEach(async () => {
		let RouteTestFactory = await ethers.getContractFactory("RouteTest")
		routeTest = await RouteTestFactory.deploy()
	})

	it("route: zero length", async () => {
		let data = Buffer.alloc(32)
		data.writeUint8(0, 31) // explicit
		let route = await routeTest.testDecode(data)
		console.log(route)
	})

	it("route: insufficient calldata", async () => {
		let data = Buffer.alloc(64)
		data.writeUint8(1, 31)
		let part: CompiledPart = {
			tokenInPtr: 0,
			tokenOutPtr: 0,
			amountInPtr: 0,
			amountOutMinPtr: 0,
			adaptorId: 1,
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
	})
})

type CompiledPart = {
	tokenInPtr: number // 2
	tokenOutPtr: number // 2
	amountInPtr: number // 2
	amountOutMinPtr: number // 2
	adaptorId: number // 1
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
