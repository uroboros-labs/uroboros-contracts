// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

/// Contains common method declarations as external methods (called via 'delegatecall')
/// and delegates them to stored implementation
library Wrapper {
	bytes32 constant IMPL_SLOT = keccak256("IMPL_SLOT");

	/// sets current implementation to forward methods
	function set(address impl) external {
		bytes32 slot = IMPL_SLOT;
		assembly {
			sstore(slot, impl)
		}
	}

	function delegate() private {
		bytes32 slot = IMPL_SLOT;
		assembly {
			let addr := sload(slot)
			let size := calldatasize()
			calldatacopy(0x0, 0x0, size)
			let ok := delegatecall(gas(), addr, 0x0, size, 0x0, 0x0)
			size := returndatasize()
			returndatacopy(0x0, 0x0, size)
			switch ok
			case 0x0 {
				revert(0x0, size)
			}
			case 0x1 {
				return(0x0, size)
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
