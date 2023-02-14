// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

library StringBuf {
	struct _StringBuf {
		string s;
		uint pos;
	}

	function write(_StringBuf memory sbuf, uint value) internal pure {
		uint next = value / 0xa;
		if (next != 0x0) write(sbuf, next);
		writeUint8(sbuf, uint8(value % 0xa) + 0x30);
	}

	function write(_StringBuf memory sbuf, uint[] memory values) internal pure {
		writeUint8(sbuf, 0x5b);
		for (uint i; i < values.length; i++) {
			write(sbuf, values[i]);
			if (i < values.length - 1) {
				writeUint8(sbuf, 0x2c);
				writeUint8(sbuf, 0x20);
			}
		}
		writeUint8(sbuf, 0x5d);
	}

	function writeUint8(_StringBuf memory sbuf, uint8 value) internal pure {
		assembly ('memory-safe') {
			let s := mload(sbuf)
			let length := mload(s)
			let pos_ptr := add(sbuf, 0x20)
			let pos := mload(pos_ptr)
			if gt(pos, length) {
				// revert
			}
			mstore(pos_ptr, add(pos, 0x1))
			let char_pos := add(s, add(0x20, pos))
			mstore8(char_pos, value)
		}
		// uint length;
		// string memory s;
		// assembly ('memory-safe') {
		// 	s := mload(sbuf)
		// 	length := mload(s)
		// }
		// require(sbuf.pos < length, 'StringBuf: out of bounds');
		// uint pos = sbuf.pos++;
		// assembly ('memory-safe') {
		// 	let ptr := add(s, add(0x20, pos))
		// 	mstore8(ptr, value)
		// }
	}
}
