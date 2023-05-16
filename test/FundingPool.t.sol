// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/FundingPool.sol";
import "../src/Hypercert.sol";

contract FundingPoolTest is Test {
    FundingPool public fundingPool;
    Hypercert public hypercert;

    address _usdcAddress = 0x0FA8781a83E46826621b3BC094Ea2A0212e71B23;

    function setUp() public {
        //set up hypercert contract
        hypercert = new Hypercert("https://rei");
        fundingPool = new FundingPool(_usdcAddress, _usdcAddress);
    }

    function testDepositFunds() public {
        address sender = msg.sender;
        uint256 amount = 100;

        //print the amount before
        // fundingPool.totalFunds();

        // Call the depositFunds function
        // donationPool.depositFunds(amount);

        // Assert that the balance of the sender has increased by the amount
        // assertEq(donationPool.balances[sender], amount);

        // Assert that the total funds has increased by the amount
        // assertEq(donationPool.totalFunds(), amount);
    }
}
