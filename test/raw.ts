// import { ethers } from "hardhat"
// import { IERC20__factory, UrbRouter } from "../typechain-types"

// describe("raw", () => {
// 	let urbRouter: UrbRouter, deployer: string

// 	beforeEach(async () => {
// 		let [signer] = await ethers.getSigners()
// 		deployer = signer.address
// 		console.log(deployer)

// 		let UrbRouter = await ethers.getContractFactory("UrbRouter")
// 		let UniswapV2Adaptor = await ethers.getContractFactory("UniswapV2Adaptor")

// 		urbRouter = await UrbRouter.deploy()
// 		await UniswapV2Adaptor.deploy()

// 		let WBNB = IERC20__factory.connect(
// 			"0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
// 			await ethers.getImpersonatedSigner("0xd7d069493685a581d27824fc46eda46b7efc0063")
// 		)
// 		await WBNB.transfer(signer.address, "100000000000000000000")

// 		WBNB = IERC20__factory.connect(WBNB.address, signer)
// 		await WBNB.approve(urbRouter.address, "0xffffffffffffffffffff")

// 		console.log("signer.balance", await WBNB.balanceOf(signer.address))
// 	})

// 	// it("test1", async () => {
// 	// 	// blockNumber=24039395
// 	// 	await urbRouter.callStatic.swap({
// 	// 		deployer,
// 	// 		parts: ["0x0000000000000000000000000000000001010100000062004801010000000028"],
// 	// 		data: "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095ce9e7cea3dedca5984780bafc599bd69add087d560000000000000000000000000000000000000000000000000de0b6b3a764000033edc4c558c4badfe050d79f565632cf910573b61e0000000001",
// 	// 	})
// 	// })

// 	it("raw", async () => {
// 		/**
// 		 * {
//     token_in: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
//     token_out: '0xe85afccdafbe7f2b096f268e31cce3da8da2990a',
//     amount_in: '0x38d7ea4c68000', // 1000000000000000
//     amount_out: '0x2f755e247b55c2c627c1dc5a0b9', // 60160755130030202223456866902201
//     gas_used: 63301,
//     swap_data: {
//       type: 'uniswap-v2',
//       address: '0x1c3bfda8d788689ab2fb935a9499c67e098a9e84',
//       swap_fee: 20,
//       sell_fee: 0,
//       buy_fee: 0,
//       zero_for_one: true
//     }
//   },
//   {
//     token_in: '0xe85afccdafbe7f2b096f268e31cce3da8da2990a',
//     token_out: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
//     amount_in: '0x2f755e247b55c2c627c1dc5a0b9', // 60160755130030202223456866902201
//     amount_out: '0x4e2291eff2a1aa', // 21993058374689194
//     gas_used: 131723,
//     swap_data: {
//       type: 'uniswap-v2',
//       address: '0x272c2cf847a49215a3a1d4bff8760e503a06f880',
//       swap_fee: 25,
//       sell_fee: 0,
//       buy_fee: 0,
//       zero_for_one: false
//     }
//   },
//   {
//     token_in: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
//     token_out: '0xe9e7cea3dedca5984780bafc599bd69add087d56',
//     amount_in: '0x4e2291eff2a1aa', // 21993058374689194
//     amount_out: '0x4b8e50598100ddeb', // 5444377344884137451
//     gas_used: 189149,
//     swap_data: {
//       type: 'uniswap-v2',
//       address: '0xed903814ef0539626206e4e7f0f34121c63228af',
//       swap_fee: 30,
//       sell_fee: 0,
//       buy_fee: 0,
//       zero_for_one: true
//     }
//   }
// 		 */
// 		await urbRouter.callStatic.swap({
// 			deployer,
// 			parts: [
// 				"0x00000000000000000000000000000000000102010100b6009c0101000000003c",
// 				"0x00000000000000000000000000000000000002010100d000b60100010000007c",
// 				"0x00000000000000000000000000000000010003000000ea00d00102000000005c",
// 			],
// 			data: "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095ce85afccdafbe7f2b096f268e31cce3da8da2990ae9e7cea3dedca5984780bafc599bd69add087d5600000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000004e2291eff2a1aa00000000000000000000000000000000000002f755e247b55c2c627c1dc5a0b91c3bfda8d788689ab2fb935a9499c67e098a9e84140000000001272c2cf847a49215a3a1d4bff8760e503a06f880190000000000ed903814ef0539626206e4e7f0f34121c63228af1e0000000001",
// 		})
// 	})
// })
