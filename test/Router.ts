import { BigNumber } from '@ethersproject/bignumber'
import { ethers } from 'hardhat'
import { ERC20, Router, UniswapV2Pair } from '../typechain-types'
import { AdaptorId, encodeRoute, encodeUniswapV2AdaptorData, Part } from './encoding'

describe('Router', () => {
	let router: Router,
		token0: ERC20,
		token1: ERC20,
		pair01: UniswapV2Pair,
		token2: ERC20,
		pair12: UniswapV2Pair

	beforeEach(async () => {
		let [signer] = await ethers.getSigners()

		let RouterFactory = await ethers.getContractFactory('Router')
		let Erc20Factory = await ethers.getContractFactory('ERC20PresetFixedSupply')
		let UniswapV2FactoryFactory = await ethers.getContractFactory('UniswapV2Factory')
		let UniswapV2PairFactory = await ethers.getContractFactory('UniswapV2Pair')

		router = await RouterFactory.deploy()

		let _feeToSetter = '0x0000000000000000000000000000000000000000'
		let uniswapV2Factory = await UniswapV2FactoryFactory.deploy(_feeToSetter)

		let initialSupply = BigNumber.from('1000000000000000000000000')
		token0 = await Erc20Factory.deploy('token0', 'token0', initialSupply, signer.address)
		token1 = await Erc20Factory.deploy('token1', 'token1', initialSupply, signer.address)
		token2 = await Erc20Factory.deploy('token1', 'token1', initialSupply, signer.address)

		await uniswapV2Factory.createPair(token0.address, token1.address)
		pair01 = UniswapV2PairFactory.attach(
			await uniswapV2Factory.getPair(token0.address, token1.address)
		)
		await token0.transfer(pair01.address, '1000000000000000000')
		await token1.transfer(pair01.address, '2000000000000000000')
		await pair01.sync()

		await uniswapV2Factory.createPair(token1.address, token2.address)
		pair12 = UniswapV2PairFactory.attach(
			await uniswapV2Factory.getPair(token1.address, token2.address)
		)
		await token1.transfer(pair12.address, '2000000000000000000')
		await token2.transfer(pair12.address, '3000000000000000000')
		await pair12.sync()
	})

	// it('router: test1', test1)
	it('router: test2', test2)

	async function test1() {
		let route: Part[] = [
			{
				tokenIn: token0.address,
				tokenOut: token1.address,
				adaptorId: AdaptorId.UniswapV2,
				amountIn: '1000000000',
				data: encodeUniswapV2AdaptorData({
					address: pair01.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token0.address, token1.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 1,
				isInput: true,
				isOutput: true,
			},
		]
		let payload = encodeRoute(route)
		let result = await router.quote(payload)
		console.log(result)
	}

	async function test2() {
		let route: Part[] = [
			{
				tokenIn: token0.address,
				tokenOut: token1.address,
				adaptorId: AdaptorId.UniswapV2,
				amountIn: '1000000000',
				data: encodeUniswapV2AdaptorData({
					address: pair01.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token0.address, token1.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 2,
				isInput: true,
				isOutput: false,
			},
			{
				tokenIn: token1.address,
				tokenOut: token2.address,
				adaptorId: AdaptorId.UniswapV2,
				data: encodeUniswapV2AdaptorData({
					address: pair12.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token1.address, token2.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 2,
				isInput: false,
				isOutput: true,
			},
		]
		let payload = encodeRoute(route)
		let result = await router.quote(payload)
		console.log(result)
	}
})

function sortTokens(token0: string, token1: string): boolean {
	return BigNumber.from(token1).gt(token0)
}
