// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/FundingPool.sol";
import "../src/Hypercert.sol";
import "../src/MockUSDC.sol";

contract Funding is Test {
	Hypercert hypercert;
	FundingPool fundingPool;
	MockUSDC mockUSDC;

	address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
	address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

	error RoundEnded(uint256 _tokenId);

	function setUp() public {
		hypercert = new Hypercert("https://something.com");
		vm.prank(alice);
		mockUSDC = new MockUSDC("USDC", "USDC", alice, 100000000000);
		fundingPool = new FundingPool(address(hypercert), address(mockUSDC));
		hypercert.setPool(address(fundingPool));

		hypercert.createGrant("first", block.timestamp + 1 days);
		hypercert.createGrant("second", block.timestamp + 1 hours);
	}

	function testDeposit() public {
		vm.startPrank(alice);
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1000854;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();
	}

	function testDepositEnded() public {
		vm.startPrank(alice);
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1000854;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 5000000);
		vm.warp(block.timestamp + 2 hours);   // warp blocktime to 2 hours later.
		vm.expectRevert(abi.encodeWithSelector(RoundEnded.selector, 1));   // expect revert with custom error.
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();
	}

	function testWithdrawal() public {
		vm.startPrank(alice);
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1000854;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();

		vm.warp(block.timestamp + 2 days); // warp blocktime to 2 days later.
		fundingPool.withdrawFunds(0, address(mockUSDC));
	}

	function testWithdrawalNotOwner() public {
		vm.startPrank(alice);
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1000854;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.warp(block.timestamp + 2 days); // warp blocktime to 2 days later.
		vm.expectRevert("Caller not creator"); // expect revert.
		fundingPool.withdrawFunds(0, address(mockUSDC));
		fundingPool.donationPoolFundsByGrantId(0);
		vm.stopPrank();
	}

	function testTreasuryWithdrawal() public {
		vm.startPrank(alice);
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1000854;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();

		vm.warp(block.timestamp + 2 days); // warp blocktime to 2 days later.
		fundingPool.withdrawFunds(0, address(mockUSDC));

		fundingPool.setTreasuryAddress(bob);
		fundingPool.treasuryWithdraw(address(mockUSDC));
	}
}