// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Hypercert.sol";

contract HypercertScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIV_KEY");
        vm.broadcast(deployerPrivateKey);

        Hypercert hypercert = new Hypercert("asd");
        hypercert.createGrant("First Grant!", block.timestamp + 300);
        hypercert.latestId();
        hypercert.grantInfo(0);

        vm.stopBroadcast();
    }
}
