import { ethers } from "hardhat";
import { RouteExecutor } from "../typechain-types";

describe("RouteExecutor", () => {
	it("works", async () => {
		let signers = await ethers.getSigners();

		console.log(signers[0].address);
		console.log(await ethers.provider.call({ data: "0x3260005260206000f3" }));

		let ERC20PresetFixedSupply = await ethers.getContractFactory("ERC20PresetFixedSupply");
		let UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
		let UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
		let UniswapV2Adaptor = await ethers.getContractFactory("UniswapV2Adaptor");
		let RouteExecutor = await ethers.getContractFactory("RouteExecutor");

		console.log("deployed adaptor:", (await UniswapV2Adaptor.deploy()).address);
		let WETH = await ERC20PresetFixedSupply.deploy(
			"Wrapped Ether",
			"WETH",
			"1000000000000000000000",
			signers[0].address
		);
		let USDC = await ERC20PresetFixedSupply.deploy("USDC", "USDC", "1000000000000000000000", signers[0].address);
		let uniswapV2Factory = await UniswapV2Factory.deploy("0x0000000000000000000000000000000000000000");
		let routeExecutor = await RouteExecutor.deploy(signers[0].address);

		console.log(WETH.address, USDC.address);

		let wethUsdcPair = await uniswapV2Factory
			.createPair(WETH.address, USDC.address)
			.then((creation) => creation.wait())
			.then((receipt) => {
				// @ts-ignore
				return UniswapV2Pair.attach(receipt.events[0].args[2]);
			});

		console.log("wethUsdcPair: ", wethUsdcPair.address);

		// WETH:USDC = 1:10
		await WETH.transfer(wethUsdcPair.address, "100000000000000000000");
		await USDC.transfer(wethUsdcPair.address, "1000000000000000000000");
		await wethUsdcPair.sync();

		await WETH.approve(routeExecutor.address, "1000000000000000000");

		let route: RouteExecutor.RoutePartStruct[] = [
			{
				tokenIn: WETH.address,
				amountIn: "1000000000000000000",
				amountOutMin: "0",
				receiver: wethUsdcPair.address,
				adaptorId: 0,
				data: "0x011900000000" + wethUsdcPair.address.slice(2),
			},
		];
		await routeExecutor.execute(route);
	});
});
