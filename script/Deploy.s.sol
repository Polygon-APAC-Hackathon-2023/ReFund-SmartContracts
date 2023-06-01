// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FundingPool.sol";
import "../src/Hypercert.sol";
import "../src/MockUSDC.sol";
import "../src/QFPool.sol";

contract HypercertScript is Script {
	Hypercert hypercert;
	FundingPool fundingPool;
	MockUSDC mockUSDC;
	QFPool qfPool;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address addr = vm.addr(vm.envUint("PRIVATE_KEY"));
		hypercert = new Hypercert();
		mockUSDC = new MockUSDC("USDC", "USDC", addr, 100000000000);
		fundingPool = new FundingPool(address(hypercert), address(mockUSDC));
		qfPool = new QFPool(address(fundingPool), address(hypercert));
		hypercert.setPool(address(fundingPool));
        vm.stopBroadcast();
    }
}
