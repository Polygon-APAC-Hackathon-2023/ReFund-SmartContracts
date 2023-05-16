// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IERC20Decimal.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

//Import Hypercert contract
import "./Hypercert.sol";

/// @title FundingPool
/// @dev This is the contract that will handle operations related to Donation Pool and QF Pool
contract FundingPool is Ownable {
    Hypercert public hypercert;
    uint256 public donationPoolFunds;

    mapping(address => bool) public allowedTokens;
    mapping(uint256 => uint256) public donationPoolFundsByTokenID;
    mapping(address => mapping(uint256 => uint256)) public fundsDepositedByAddress;

    /// @notice Event to track that funds have been deposited
    /// @param _from - the address of the donor
    /// @param _tokenID - the tokenID of the token deposited
    /// @param _value - the amount of funds deposited
    event FundsDeposited(
        address indexed _from,
        uint256[] _tokenID,
        uint256[] _value
    );
    event FundsWithdrawed(uint256 indexed _tokenId, uint256 _amount, address indexed _creator);

    error GrantNotExist();

    constructor(address _hypercert, address _defaultToken) {
        hypercert = Hypercert(_hypercert);
        allowedTokens[_defaultToken] = true;
    }

    ///@notice Function to allow only a specific token to be deposited
    ///@dev Only the owner of the contract can call this function
    ///@param _token - the address of the token to be allowed
    function allowToken(address _token) public onlyOwner {
        allowedTokens[_token] = true;
    }

    ///@notice Function to deposit funds into the donation pool
    ///@dev One address can deposit in batch for multiple tokenIDs
    function depositFunds(
        uint256[] calldata _grantIds,
        uint256[] calldata  _depositFunds,
        uint256 _cumulativeTotal,
        address _token
    ) external payable {
        //the transfer happens once for all the tokenIDs
        require(allowedTokens[_token] == true, "Token is not allowed/supported");
        require(
            IERC20Decimal(_token).allowance(msg.sender, address(this)) >= _cumulativeTotal,
            "Not approved to send balance requested"
        );
        bool success = IERC20Decimal(_token).transferFrom(
            msg.sender,
            address(this),
            _cumulativeTotal
        );
        require(success, "Transaction was not successful");

        donationPoolFunds += _cumulativeTotal;
        uint256[] memory roundedFunds;

        //only after the transfer is successful, the data can be accordingly updated
        for (uint256 i; i < _grantIds.length; ) {
            if (_grantIds[i] > hypercert.latestUnusedId()) {
                revert GrantNotExist();
            }
            donationPoolFundsByTokenID[_grantIds[i]] += _depositFunds[i];
            fundsDepositedByAddress[msg.sender][_grantIds[i]] += _depositFunds[i];
            roundedFunds[i] = _depositFunds[i] / (10 ** IERC20Decimal(_token).decimals());
            unchecked {
                i++;
            }
        }
        //emit event to track that funds have been deposited
        emit FundsDeposited(
            msg.sender,
            _grantIds,
            _depositFunds
        );
        //call the function to mint the tokens
        hypercert.mintBatch(msg.sender, _grantIds, roundedFunds, "");
    }

    ///@notice Function to withdraw funds from the donation pool
    ///@notice Certain portion of funds will be transferred to the QF pool
    ///@dev Check that only the grant creator can call this function
    ///@dev Check that the grant period has ended before calling this function
    ///@dev Update the value of funds in the donation pool
    ///@dev The value to withdraw is read from donationPoolFundsByTokenID
    ///@param _tokenID - the tokenID of the token to withdraw
    ///@param _token - the address of the token to withdraw
    function withdrawFunds(uint256 _tokenID, address _token) external {
        if (_tokenID < hypercert.latestUnusedId()) {
            revert GrantNotExist();
        }
        require(hypercert.grantEnded(_tokenID), "Not ended");
        require(hypercert.grantOwner(_tokenID) == msg.sender, "Not creator");
        require(allowedTokens[_token] == true, "Token is not allowed/supported");
        bool success = IERC20Decimal(_token).transferFrom(
            address(this),
            msg.sender,
            donationPoolFundsByTokenID[_tokenID]
        );
        require(success, "Transaction was not successful");

        emit FundsWithdrawed(_tokenID, donationPoolFundsByTokenID[_tokenID], msg.sender);

        //update the value of funds in the donation pool
        donationPoolFunds -= donationPoolFundsByTokenID[_tokenID];
    }
}
