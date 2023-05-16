// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract MockUSDC is ERC20Mock {
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) payable ERC20Mock(name, symbol, initialAccount, initialBalance) {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
	}
}