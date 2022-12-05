import { ethers } from "hardhat"
import { expect } from "chai"
import { Relay, UniswapV2Loader, ERC20TransferFee, UniswapV2Pair } from "../../typechain-types"

describe("UniswapV2", () => {
	let pairImpl: UniswapV2Pair,
		loader: UniswapV2Loader,
		relay: Relay,
		tokenA: ERC20TransferFee,
		tokenB: ERC20TransferFee

	beforeEach(async () => {
		let [Relay, ERC20TransferFee, UniswapV2Pair] = await Promise.all([
			ethers.getContractFactory("Relay"),
			ethers.getContractFactory("ERC20TransferFee"),
			ethers.getContractFactory("UniswapV2Pair"),
		])

		let Wrapper = await ethers.getContractFactoryFromArtifact(
			require("../../artifacts/contracts/loader/libraries/Wrapper.sol/Wrapper.json")
		)
		let wrapper = await Wrapper.deploy()

		let UniswapV2Loader = await ethers.getContractFactory("UniswapV2Loader", {
			libraries: {
				Wrapper: wrapper.address,
			},
		})

		pairImpl = await UniswapV2Pair.deploy()
		relay = await Relay.deploy()
		tokenA = await ERC20TransferFee.deploy("A", "A", "1000000000000000000000")
		tokenB = await ERC20TransferFee.deploy("B", "B", "1000000000000000000000")
		loader = await UniswapV2Loader.deploy(relay.address, pairImpl.address)

		let pair = UniswapV2Pair.attach(loader.address)
		await pair.initialize(tokenA.address, tokenB.address)
		await tokenA.transfer(loader.address, "10000000000000000000")
		await tokenB.transfer(loader.address, "10000000000000000000")
		await pair.sync()

		await tokenA.setTransferFromFee(loader.address, 300) // buy
		await tokenA.setTransferToFee(loader.address, 700) // sell

		await tokenB.setTransferToFee(loader.address, 100) // sell
	})

	it("works", async () => {
		let data = await loader.callStatic.load(pairImpl.address)
		console.log(data)
		expect(data.name).eq("Uniswap V2")
		expect(data.token0).eq(tokenA.address)
		expect(data.token1).eq(tokenB.address)
		expect(data.reserve0).eq("10000000000000000000")
		expect(data.reserve1).eq("10000000000000000000")
		expect(data.swap).eq(30)
		expect(data.buy0).eq(300)
		expect(data.sell0).eq(700)
		expect(data.buy1).eq(0)
		expect(data.sell1).eq(100)
	})
})
