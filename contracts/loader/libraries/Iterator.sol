// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library Iterator {
	struct It {
		bytes data;
		uint curr;
	}

	function iter(bytes memory data) internal pure returns (It memory it) {
		it.data = data;
	}

	function readUint(It memory it) internal pure bounded(it, 0x20) returns (uint256 x) {
		assembly {
			x := mload(add(mload(it), 0x20))
		}
	}

	function writeUint(It memory it, uint x) internal pure bounded(it, 0x20) {
		assembly {
			mstore(mload(add(mload(it), 0x20)), x)
		}
	}

	modifier bounded(It memory it, uint length) {
		require(it.data.length > it.curr + length);
		_;
		it.curr += length;
	}
}
