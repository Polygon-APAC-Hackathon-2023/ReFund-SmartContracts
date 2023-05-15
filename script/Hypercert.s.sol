// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Hypercert.sol";

contract HypercertScript is Script {
    function run() public {
        vm.broadcast();

        Hypercert hypercert = new Hypercert("asd");
        hypercert.createGrant("First Grant!", block.timestamp + 300);
        hypercert.latestUnusedId();
        hypercert.grantInfo(0);

        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        vm.startPrank(alice);

        hypercert.createGrant("Second Grant", block.timestamp +300);
        hypercert.latestUnusedId();
        hypercert.grantInfo(1);

        vm.stopPrank();
    }
}
