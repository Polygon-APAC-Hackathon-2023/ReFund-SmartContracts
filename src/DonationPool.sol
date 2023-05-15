// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title IMockGrantCreate
/// @dev This is the interface for the MockGrantCreate contract
/// @notice Used to attach to contract responsible to create hypercerts.
interface IMockGrantCreate {
    function setCreator(uint256 _tokenId, address _creator) external;

    function getCreator(uint256 _tokenId) external view returns (address);

    function exists(uint256 _tokenId) external view returns (bool);
}

/// @title FundingPool
/// @dev This is the contract that will handle operations related to Donation Pool and QF Pool

//TODO: add a control check to ensure only USDC is accepted
//TODO: add allowance for USDC
contract FundingPool {
    IMockGrantCreate public mockGrantCreate;

    /// @notice Event to track that funds have been deposited
    /// @param tokenID the tokenID of the hypercert
    /// @param _from - the address of the donor
    /// @param _value - the amount of funds deposited
    event FundsDeposited(
        uint256 indexed tokenID,
        address indexed _from,
        uint256 indexed _value
    );

    constructor(address _hypercert) {
        mockGrantCreate = IMockGrantCreate(_hypercert);
    }

    //declare a variable to track the value of funds in donation pool, accept multiple decimal places
    uint256 public donationPoolFunds;
}
