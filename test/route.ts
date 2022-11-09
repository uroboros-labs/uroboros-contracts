import { encodePacked } from "web3-utils"

export type SwapData =
	| {
			type: "uniswap-v2"
			address: string
			swap_fee: number
			buy_fee: number
			sell_fee: number
			rev: boolean
	  }
	| {
			type: "uniswap-v3"
	  }
	| {
			type: "balancer-v2"
	  }
	| {
			type: "curve"
	  }

export type RoutePart = {
	gas_used: number
	amount_in?: string
	amount_out: string
	token_in: string
	swap_data: SwapData
}

export type SwapPart = {
	amountInIdx: number
	amountOutMinIdx: number
	tokenInIdx: number
	tokenOutIdx: number
	adaptorId: number
	dataStart: number
	dataEnd: number
	sectionId: number
	sectionDepth: number
	sectionEnd: number
}

export function encodeSwapData(swapData: SwapData): { adaptorId: number; data: string } {
	switch (swapData.type) {
		case "uniswap-v2":
			return {
				adaptorId: 0x1,
				data: encodePacked(
					swapData.address,
					swapData.swap_fee,
					swapData.buy_fee,
					swapData.sell_fee,
					swapData.rev
				)!,
			}
		default:
			throw "not implemented"
	}
}

function findIndexOrPush<T>(arr: T[], item: T): number {
	let index = arr.findIndex(arrItem => arrItem === item)
	if (index === -1) {
		index = arr.length
		arr.push(item)
	}
	return index
}

export function encodeRoute(routeParts: RoutePart[]): any {
	let parts: string[] = []
	let amounts: string[] = []
	let tokens: string[] = []
	let data: string = ""
	let swapParts = routeParts.forEach(part => {
		let { adaptorId, data: swapData } = encodeSwapData(part.swap_data)
		let dataStart = data.length / 2
		let dataEnd = dataStart + swapData.length / 2
		let tokenInIdx = findIndexOrPush(tokens, part.token_in)
		// let tokenOutIdx = findIndexOrPush(tokens, part.token_in) todo tokenOut
		let tokenOutIdx = 0x0
		let swapPart: SwapPart = {
			adaptorId,
			dataStart,
			dataEnd,
			tokenInIdx,
			tokenOutIdx,
		}
		return swapPart
	})
}
