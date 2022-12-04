import { ethers } from "hardhat"
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
		await tokenA.setTransferFromFee(loader.address, 300) // buy
		await tokenA.setTransferToFee(loader.address, 700) // sell

		let pair = UniswapV2Pair.attach(loader.address)
		await pair.initialize(tokenA.address, tokenB.address)
		await tokenA.transfer(loader.address, "10000000000000000000")
		await tokenB.transfer(loader.address, "10000000000000000000")
		await pair.sync()
	})

	it("works", async () => {
		console.log(await loader.callStatic.loadRaw(pairImpl.address))
	})
})
