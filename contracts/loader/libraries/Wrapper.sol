// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

library Wrapper {
	bytes32 constant IMPL_SLOT = keccak256("IMPL_SLOT");

	function set(address impl) external {
		bytes32 slot = IMPL_SLOT;
		assembly {
			sstore(slot, impl)
		}
	}

	function delegate() private {
		bytes32 slot = IMPL_SLOT;
		assembly {
			let impl := sload(slot)
			let size := calldatasize()
			calldatacopy(0, 0, size)
			let ok := delegatecall(gas(), impl, 0, size, 0, 0)
			size := returndatasize()
			returndatacopy(0, 0, size)
			switch ok
			case 0 {
				revert(0, size)
			}
			case 1 {
				return(0, size)
			}
		}
	}

	modifier delegates() {
		delegate();
		_;
	}

	function getReserves() external delegates returns (uint112, uint112, uint32) {}

	function token0() external delegates returns (address) {}

	function token1() external delegates returns (address) {}

	function sync() external delegates {}

	function name() external delegates returns (string memory) {}

	function swap(uint, uint, address, bytes memory) external delegates {}
}
