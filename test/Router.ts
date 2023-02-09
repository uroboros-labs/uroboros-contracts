import { BigNumber, BigNumberish } from '@ethersproject/bignumber'
import { ethers } from 'hardhat'
import { ERC20, Router, UniswapV2Factory, UniswapV2Pair } from '../typechain-types'
import { AdaptorId, encodeRoute, encodeUniswapV2AdaptorData, Part } from './encoding'

describe('Router', () => {
	let router: Router,
		token0: ERC20,
		token1: ERC20,
		pair01: UniswapV2Pair,
		token2: ERC20,
		pair12: UniswapV2Pair,
		pair02: UniswapV2Pair

	beforeEach(async () => {
		async function createPair(
			uniswapV2Factory: UniswapV2Factory,
			token0: ERC20,
			token1: ERC20,
			reserve0: BigNumberish,
			reserve1: BigNumberish
		): Promise<UniswapV2Pair> {
			await uniswapV2Factory.createPair(token0.address, token1.address)
			let pair = UniswapV2PairFactory.attach(
				await uniswapV2Factory.getPair(token0.address, token1.address)
			)
			await token0.transfer(pair.address, reserve0)
			await token1.transfer(pair.address, reserve1)
			await pair.sync()
			return pair
		}

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

		pair01 = await createPair(
			uniswapV2Factory,
			token0,
			token1,
			'1000000000000000000',
			'2000000000000000000'
		)

		pair12 = await createPair(
			uniswapV2Factory,
			token1,
			token2,
			'2000000000000000000',
			'3000000000000000000'
		)

		pair02 = await createPair(
			uniswapV2Factory,
			token0,
			token2,
			'1000000000000000000',
			'1000000000000000000'
		)
	})

	// it('router: test1', test1)
	it('router: test2', test2)
	it('router: test3', test3)

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
		let { data } = encodeRoute(route)
		let result = await router.quote(data)
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
		let { data } = encodeRoute(route)
		let result = await router.quote(data)
		console.log(result)
	}

	async function test3() {
		let route: Part[] = [
			{
				tokenIn: token0.address,
				tokenOut: token2.address,
				adaptorId: AdaptorId.UniswapV2,
				amountIn: '1000000000',
				data: encodeUniswapV2AdaptorData({
					address: pair02.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token0.address, token2.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 3,
				isInput: true,
				isOutput: false,
			},
			{
				tokenIn: token2.address,
				tokenOut: token1.address,
				adaptorId: AdaptorId.UniswapV2,
				data: encodeUniswapV2AdaptorData({
					address: pair12.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token2.address, token1.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 3,
				isInput: false,
				isOutput: false,
			},
			{
				tokenIn: token1.address,
				tokenOut: token0.address,
				adaptorId: AdaptorId.UniswapV2,
				data: encodeUniswapV2AdaptorData({
					address: pair01.address,
					swapFee: 30,
					sellFee: 0,
					buyFee: 0,
					zeroForOne: sortTokens(token1.address, token0.address),
				}),
				sectionId: 0,
				sectionDepth: 0,
				sectionEnd: 3,
				isInput: false,
				isOutput: true,
			},
		]
		let { data } = encodeRoute(route)
		let result = await router.quote(data)
		console.log(result)
	}
})

function sortTokens(token0: string, token1: string): boolean {
	return BigNumber.from(token1).gt(token0)
}
