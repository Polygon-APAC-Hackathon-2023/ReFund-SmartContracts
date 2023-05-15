// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../src/DonationPool.sol";

// contract DonationPoolTest is Test {
//     DonationPool public donationPool;

//     address _usdcAddress = 0x0FA8781a83E46826621b3BC094Ea2A0212e71B23;

//     function setUp() public {
//         donationPool = new DonationPool(_usdcAddress);
//     }

//     function testDepositFunds() public {
//         address sender = msg.sender;
//         uint256 amount = 100;

//         //print the amount before
//         donationPool.totalFunds();

//         // Call the depositFunds function
//         // donationPool.depositFunds(amount);

//         // Assert that the balance of the sender has increased by the amount
//         // assertEq(donationPool.balances[sender], amount);

//         // Assert that the total funds has increased by the amount
//         // assertEq(donationPool.totalFunds(), amount);
//     }
// }
