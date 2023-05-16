// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

//Import Hypercert contract
import "./Hypercert.sol";

/// @title FundingPool
/// @dev This is the contract that will handle operations related to Donation Pool and QF Pool
contract FundingPool is Ownable {
    Hypercert public hypercert;

    ///@dev Struct to store tokenID and respective value deposited
    struct DepositFunds {
        uint256 tokenID;
        uint256 value;
    }

    ///@dev Variable to store an array of tokenIDs
    uint256[] public tokenIDs;

    ///@dev Variable to store an array of zero-decimal value of tokens
    uint256[] public tokenValues;

    ///@dev Variable to store arbitrary data
    bytes data;

    ///@dev The allowed tokens for user to donate
    mapping(address => bool) public allowedTokens;

    ///@dev Track the value of funds in donation pool
    uint256 public donationPoolFunds;

    ///@dev Track the value of funds in donation pool by tokenID
    mapping(uint256 => uint256) public donationPoolFundsByTokenID;

    ///@dev Track the value of funds deposited by an address for a tokenID of a specific amount
    mapping(address => mapping(uint256 => uint256))
        public fundsDepositedByAddress;

    /// @notice Event to track that funds have been deposited
    /// @param _from - the address of the donor
    /// @param _tokenID - the tokenID of the token deposited
    /// @param _value - the amount of funds deposited
    event FundsDeposited(
        address indexed _from,
        uint256 indexed _tokenID,
        uint256 _value
    );

    ///@dev Modifier to check that the person calling the function is the grant creator
    modifier onlyGrantCreator(address _grantCreator) {
        require(
            hypercert._grantCreatorExists(_grantCreator),
            "Only grant creator can call this function"
        );
        _;
    }

    ///@dev Modifier to check that the grant period of tokenID has ended
    modifier grantPeriodHasEnded(uint256 _tokenID) {
        require(
            hypercert._grantPeriodHasEnded(_tokenID),
            "Grant period has not ended"
        );
        _;
    }

    constructor(address _hypercert, address _defaultToken) {
        hypercert = Hypercert(_hypercert);
        allowedTokens[_defaultToken] = true;
    }

    ///@notice Function to allow only a specific token to be deposited
    ///@dev Only the owner of the contract can call this function
    ///@param _token - the address of the token to be allowed
    function allowAddress(address _token) public onlyOwner {
        allowedTokens[_token] = true;
    }

    ///@notice Function to deposit funds into the donation pool
    ///@dev One address can deposit in batch for multiple tokenIDs
    ///@param _depositFunds - an array of structs that stores the tokenID and the respective value to deposit
    function depositFunds(
        DepositFunds[] memory _depositFunds,
        uint256 _cumulativeTotal,
        address _token
    ) external payable {
        //the transfer happens once for all the tokenIDs
        require(
            allowedTokens[_token] == true,
            "Token is not allowed/supported"
        );
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= 0,
            "Not approved to send balance requested"
        );
        bool success = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _cumulativeTotal
        );
        require(success, "Transaction was not successful");

        //update the value of funds in the donation pool
        donationPoolFunds += _cumulativeTotal;

        //only after the transfer is successful, the data can be accordingly updated
        for (uint256 i; i < _depositFunds.length; ) {
            //update the value of funds deposited by the address
            fundsDepositedByAddress[msg.sender][
                _depositFunds[i].tokenID
            ] += _depositFunds[i].value;

            //update the value of funds in the donation pool by tokenID
            donationPoolFundsByTokenID[
                _depositFunds[i].tokenID
            ] += _depositFunds[i].value;

            //emit event to track that funds have been deposited
            emit FundsDeposited(
                msg.sender,
                _depositFunds[i].tokenID,
                _depositFunds[i].value
            );

            //update the tokenIDs and tokenValues arrays
            tokenIDs.push(_depositFunds[i].tokenID);

            //convert the value to round
            uint256 value = convertToRound(_depositFunds[i].value);

            tokenValues.push(value);

            unchecked {
                i++;
            }
        }

        //call the function to mint the tokens
        hypercert._mintBatchExternal(msg.sender, tokenIDs, tokenValues, data);
    }

    ///@notice Function to withdraw funds from the donation pool
    ///@notice Certain portion of funds will be transferred to the QF pool
    ///@dev Check that only the grant creator can call this function
    ///@dev Check that the grant period has ended before calling this function
    ///@dev Update the value of funds in the donation pool
    ///@dev The value to withdraw is read from donationPoolFundsByTokenID
    ///@param _tokenID - the tokenID of the token to withdraw
    ///@param _token - the address of the token to withdraw
    function withdrawFunds(uint256 _tokenID, address _token) external onlyGrantCreator(msg.sender) grantPeriodHasEnded(_tokenID){
        //the transfer happens once for all the tokenIDs
        require(
            allowedTokens[_token] == true,
            "Token is not allowed/supported"
        );
        require(
            IERC20(_token).allowance(address(this), msg.sender) >= 0,
            "Not approved to send balance requested"
        );
        bool success = IERC20(_token).transferFrom(
            address(this),
            msg.sender,
            donationPoolFundsByTokenID[_tokenID]
        );
        require(success, "Transaction was not successful");
        
        //update the value of funds in the donation pool
        donationPoolFunds -= donationPoolFundsByTokenID[_tokenID];

        //transfer the funds to the QF pool
        // hypercert.transferFundsToQFPool(_tokenID);
    }

    ///@dev Function to convert the decimal value of the token to round
    function convertToRound(
        uint256 decimalValue
    ) public pure returns (uint256) {
        return decimalValue / 1;
    }
}
