// SPDX-License-Identifier: No license
pragma solidity >=0.8.17;

import "../Route.sol";
import "hardhat/console.sol";

contract RouteTest {
	function testDecode(bytes calldata payload) external view returns (Route.Part[] memory) {
		uint gas = gasleft();
		Route.Part[] memory route = Route.decode(payload);
		gas -= gasleft();
		uint memorySize;
		assembly ("memory-safe") {
			memorySize := mload(0x40)
		}
		console.log("gasUsed: %s, memorySize: %s", gas, memorySize);
		return route;
	}
}
