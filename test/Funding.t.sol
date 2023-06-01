// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/FundingPool.sol";
import "../src/Hypercert.sol";
import "../src/MockUSDC.sol";
import "../src/QFPool.sol";

contract Funding is Test {
	Hypercert hypercert;
	FundingPool fundingPool;
	MockUSDC mockUSDC;
	QFPool qfPool;

	address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
	address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

	error RoundEnded(uint256 _tokenId);

	function setUp() public {
		hypercert = new Hypercert();
		vm.prank(alice);
		mockUSDC = new MockUSDC("USDC", "USDC", alice, 100000000000);
		fundingPool = new FundingPool(address(hypercert), address(mockUSDC));
		qfPool = new QFPool(address(fundingPool), address(hypercert));
		hypercert.setPool(address(fundingPool));

		hypercert.createGrant("first", block.timestamp + 1 days, "firstURI");
		hypercert.createGrant("second", block.timestamp + 32 days, "secondURI");
	}

	function testDeposit() public {
		vm.startPrank(alice);

		/// Deposit USDC
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
		
		/// Deposit USDC
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

		vm.warp(block.timestamp + 50 days);   // warp blocktime to 50 days later.

		/// Deposit to ended grant
		vm.expectRevert(abi.encodeWithSelector(RoundEnded.selector, 0));   // expect revert with custom error.
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();
	}

	function testWithdrawal() public {
		vm.startPrank(alice);
		
		/// Deposit USDC
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

	function testTreasuryWithdrawal() public {
		vm.startPrank(alice);

		/// Deposit USDC
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

		/// Test treasury withdrawal
		fundingPool.setTreasuryAddress(bob);
		vm.prank(bob);
		fundingPool.treasuryWithdraw(address(mockUSDC));
	}

	function testMultipleApprovedTokens() public {
		/// Mock USDT
		MockUSDC mockUSDT = new MockUSDC("USDT", "USDT", alice, 100000000000);
		fundingPool.allowToken(address(mockUSDT), true);

		vm.startPrank(alice);

		/// Deposit USDC
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

		/// Reset to deposit USDT
		total = 0;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000 * i + 1235468;
			total += amounts[i];
		}
		mockUSDT.approve(address(fundingPool), 5000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDT));

		/// Check balance
		hypercert.balanceOfBatch(addrs, ids);
		fundingPool.fundInfoByAddress(alice);
		vm.stopPrank();
	}

	function testQFPoolDistribution() public {
		vm.startPrank(alice);

		/// Deposit 1000USDC to grantId 0 and 2000USDC to grantId 1
		uint256[] memory ids = new uint256[](2);
		uint256[] memory amounts = new uint256[](2);
		address[] memory addrs = new address[](2);
		uint256 total;
		for (uint256 i; i < uint256(2); i++) {
			addrs[i] = alice;
			ids[i] = i;
			amounts[i] = 1000000000 * i + 1000000000;
			total += amounts[i];
		}
		mockUSDC.approve(address(fundingPool), 50000000000);
		fundingPool.depositFunds(ids, amounts, total, address(mockUSDC));
		hypercert.balanceOfBatch(addrs, ids);
		vm.stopPrank();

		vm.warp(block.timestamp + 50 days); // warp blocktime to 50 days later.
		fundingPool.withdrawFunds(0, address(mockUSDC));
		fundingPool.withdrawFunds(1, address(mockUSDC));

		/// Test QF withdrawal from FundingPool
		fundingPool.setQFAddress(address(qfPool));
		qfPool.withdrawFromFundingPool(address(mockUSDC));
		qfPool.thisBalances(address(mockUSDC));

		/// Should allocate everything to grantId 1 as grantId 0 has passed eligibility of 30 days.
		qfPool.distributeFunds(address(mockUSDC));
		qfPool.allotmentsByIdToken(1, address(mockUSDC));

		/// Withdraw funds from QFPool to grant creator.
		mockUSDC.balanceOf(address(this));
		qfPool.withdrawFunds(1, address(mockUSDC));
		mockUSDC.balanceOf(address(this));
	}
}