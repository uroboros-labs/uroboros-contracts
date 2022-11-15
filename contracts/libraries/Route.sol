// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library Route {
	// struct RoutePart {
	// 	address tokenIn; // length 20
	// 	address receiver; // length 20
	// 	uint256 amountIn; // length 32
	// 	uint256 protocolId; // length 8
	// 	bytes data;
	// }

	uint256 constant TOKEN_IN = 1;
	uint256 constant RECEIVER = 1 << 1;
	uint256 constant AMOUNT_IN = 1 << 2;
	uint256 constant PROTOCOL_ID = 1 << 3;
	uint256 constant DATA = 1 << 4;

	// [route.length]([part.flags][tokenIn?][receiver?][amountIn?][protocolId?]([data.length][data]?)*,)

	function getLength(bytes memory route) internal pure returns (uint256 len) {
		assembly {
			len := shr(0xf8, mload(route))
		}
	}

	function getOffset(bytes memory route, uint256 index) internal pure returns (uint256 oft) {
		require(index < getLength(route), "Route: index out of bounds");
		// iterates through segments and adds to offset
		assembly {
			oft := add(route, 0x1)
			for {
				let i := 0x0
			} lt(i, index) {
				i := add(i, 0x1)
			} {
				let flags := shr(0xf8, mload(add(route, oft)))
				oft := add(oft, mul(and(flags, TOKEN_IN), 0x14))
				oft := add(oft, mul(and(flags, RECEIVER), 0x14))
				oft := add(oft, mul(and(flags, AMOUNT_IN), 0x20))
				oft := and(oft, mul(and(flags, PROTOCOL_ID), 0x1))
				if and(flags, DATA) {
					let length := shr(0xf8, mload(add(route, oft)))
					oft := add(oft, 0x1) // length
					oft := add(oft, length)
				}
			}
		}
		// hope it wont explode
	}

	function hasAmountIn(bytes memory route, uint256 index) internal pure returns (bool has) {
		uint256 offset = getOffset(route, index);
		assembly {
			has := and(mload(add(route, offset)), AMOUNT_IN)
		}
	}

	function hasTokenIn(bytes memory route, uint256 index) internal pure returns (bool has) {
		uint256 offset = getOffset(route, index);
		assembly {
			has := and(mload(add(route, offset)), TOKEN_IN)
		}
	}

	function hasReceiver(bytes memory route, uint256 index) internal pure returns (bool has) {
		uint256 offset = getOffset(route, index);
		assembly {
			has := and(mload(add(route, offset)), RECEIVER)
		}
	}

	function hasProtocolId(bytes memory route, uint256 index) internal pure returns (bool has) {
		uint256 offset = getOffset(route, index);
		assembly {
			has := and(mload(add(route, offset)), PROTOCOL_ID)
		}
	}

	function hasData(bytes memory route, uint256 index) internal pure returns (bool has) {
		uint256 offset = getOffset(route, index);
		assembly {
			has := and(mload(add(route, offset)), DATA)
		}
	}

	function getTokenIn(bytes memory route, uint256 index) internal pure returns (address token) {
		uint256 oft = getOffset(route, index);
		require(hasTokenIn(route, index), "Route: no tokenIn");
		assembly {
			let flags := shr(0xf8, mload(add(route, oft)))
			token := mload(add(route, oft))
		}
	}

	function getReceiver(bytes memory route, uint256 index)
		internal
		pure
		returns (address receiver)
	{
		uint256 oft = getOffset(route, index);
		require(hasReceiver(route, index), "Route: no receiver");
		assembly {
			let flags := shr(0xf8, mload(add(route, oft)))
			oft := add(oft, mul(and(flags, TOKEN_IN), 0x14))
			receiver := mload(add(route, oft))
		}
	}

	function getAmountIn(bytes memory route, uint256 index)
		internal
		pure
		returns (address amountIn)
	{
		uint256 oft = getOffset(route, index);
		require(hasAmountIn(route, index), "Route: no amountIn");
		assembly {
			let flags := shr(0xf8, mload(add(route, oft)))
			oft := add(oft, mul(and(flags, TOKEN_IN), 0x14))
			oft := add(oft, mul(and(flags, RECEIVER), 0x14))
			amountIn := mload(add(route, oft))
		}
	}

	function getProtocolId(bytes memory route, uint256 index)
		internal
		pure
		returns (address protocolId)
	{
		uint256 oft = getOffset(route, index);
		require(hasProtocolId(route, index), "Route: no protocolId");
		assembly {
			let flags := shr(0xf8, mload(add(route, oft)))
			oft := add(oft, mul(and(flags, TOKEN_IN), 0x14))
			oft := add(oft, mul(and(flags, RECEIVER), 0x14))
			oft := add(oft, mul(and(flags, AMOUNT_IN), 0x20))
			protocolId := mload(add(route, oft))
		}
	}

	function getData(bytes memory route, uint256 index) internal pure returns (bytes memory data) {
		uint256 oft = getOffset(route, index);
		require(hasData(route, index), "Route: no data");
		assembly {
			let flags := shr(0xf8, mload(add(route, oft)))
			oft := add(oft, mul(and(flags, TOKEN_IN), 0x14))
			oft := add(oft, mul(and(flags, RECEIVER), 0x14))
			oft := add(oft, mul(and(flags, AMOUNT_IN), 0x20))
			oft := and(oft, mul(and(flags, PROTOCOL_ID), 0x1))
			data := add(oft, 0x1)
		}
	}
}
