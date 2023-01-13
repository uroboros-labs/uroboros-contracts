import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@nomiclabs/hardhat-solhint"
import "hardhat-docgen"

const config: HardhatUserConfig = {
	solidity: {
		version: "0.8.17",
		settings: {
			optimizer: {
				enabled: true,
				runs: 20000,
			},
		},
	},
	// networks: {
	// 	hardhat: {
	// 		forking: {
	// 			blockNumber: 24705000,
	// 			url: "https://rpc.ankr.com/bsc",
	// 		},
	// 		accounts: [
	// 			{
	// 				// safe
	// 				privateKey: "8b248efef2761fdc4f0cd11fc9d6d21951bcdbfa53bcadd55a6ae19cf8909a3b",
	// 				balance: "1000000000000000000",
	// 			},
	// 		],
	// 	},
	// },
}

export default config
