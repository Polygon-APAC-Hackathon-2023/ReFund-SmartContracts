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
		hypercert = new Hypercert();
		vm.prank(alice);
		mockUSDC = new MockUSDC("USDC", "USDC", alice, 100000000000);
		fundingPool = new FundingPool(address(hypercert), address(mockUSDC));
		hypercert.setPool(address(fundingPool));

		hypercert.createGrant("first", block.timestamp + 1 days, "firstURI");
		hypercert.createGrant("second", block.timestamp + 1 hours, "secondURI");
	}

	function testDeposit() public {
		vm.startPrank(alice);

		// Deposit USDC
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
		
		// Deposit USDC
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

		// Deposit to ended grant
		vm.expectRevert(abi.encodeWithSelector(RoundEnded.selector, 1));   // expect revert with custom error.
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();
	}

	function testWithdrawal() public {
		vm.startPrank(alice);
		
		// Deposit USDC
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

		// Deposit USDC
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

		// Test withdrawal from Alice
		vm.expectRevert("Caller not creator"); // expect revert.
		fundingPool.withdrawFunds(0, address(mockUSDC));
		fundingPool.donationPoolFundsByGrantId(0, address(mockUSDC));
		vm.stopPrank();
	}

	function testTreasuryWithdrawal() public {
		vm.startPrank(alice);

		// Deposit USDC
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

		// Test treasury withdrawal
		fundingPool.setTreasuryAddress(bob);
		fundingPool.treasuryWithdraw(address(mockUSDC));
	}

	function testMultipleApprovedTokens() public {
		// Mock USDT
		MockUSDC mockUSDT = new MockUSDC("USDT", "USDT", alice, 100000000000);
		fundingPool.allowToken(address(mockUSDT), true);

		vm.startPrank(alice);

		// Deposit USDC
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

		// Reset to deposit USDT
		total = 0;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1235468;
			total += amounts[i];
		}
		mockUSDT.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDT));

		// Check balance
		hypercert.balanceOfBatch(addrs, ids);
		fundingPool.fundInfoByAddress(alice);
		vm.stopPrank();
	}
}