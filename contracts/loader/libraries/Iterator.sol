// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library Iterator {
	struct It {
		uint start;
		uint end;
	}

	function iter(bytes memory data) internal pure returns (It memory it) {
		uint start;
		assembly {
			start := add(data, 0x20)
		}
		it.start = start;
		it.end = start + data.length;
	}

	function writeUint(It memory it, uint x, uint bits) internal pure bounded(it, bits / 8) {
		uint start = it.start;
		x <<= 256 - bits;
		assembly {
			mstore(start, x)
		}
	}

	function writeUint16(It memory it, uint16 x) internal pure {
		writeUint(it, x, 16);
	}

	function writeUint32(It memory it, uint32 x) internal pure {
		writeUint(it, x, 32);
	}

	function writeUint160(It memory it, uint160 x) internal pure {
		writeUint(it, x, 160);
	}

	function writeUint256(It memory it, uint256 x) internal pure {
		writeUint(it, x, 256);
	}

	function writeAddress(It memory it, address x) internal pure {
		writeUint160(it, uint160(x));
	}

	function writeBytes(It memory it, bytes memory data) internal view bounded(it, data.length) {
		uint dst = it.start;
		assembly {
			let len := mload(data)
			let src := add(data, 0x20)
			// Precompiled Contract: Identity
			let x := staticcall(gas(), 0x4, src, len, dst, len)
		}
	}

	function writeString(It memory it, string memory str) internal view {
		writeBytes(it, bytes(str));
	}

	modifier bounded(It memory it, uint length) {
		require(it.start + length <= it.end, "insufficient length");
		_;
		it.start += length;
	}
}
