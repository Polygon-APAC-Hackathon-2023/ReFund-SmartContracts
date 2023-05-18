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
    address public treasuryAddress;
    address public qFAddress;
    uint256 public donationPoolFunds;
    uint256 public treasuryFunds;
    uint256 public quadraticFundingPoolFunds;
    uint256 public treasuryShare = 2; // 2%
    uint256 public quadraticFundingPoolShare = 3; // 3%
    uint256 private constant precision = 10 ** 2; // precision made for percentage

    mapping(address => bool) public allowedTokens;
    mapping(uint256 => uint256) public donationPoolFundsByGrantId;
    mapping(address => mapping(uint256 => uint256)) public fundsDepositedByAddress;

    event FundsDeposited(
        address indexed _from,
        uint256[] _grantId,
        uint256[] _value,
        uint256 _cumulativeTotal
    );
    event FundsWithdrawed(uint256 indexed _grantId, uint256 _amount, address indexed _creator);
    event FundsTransferredToTreasuryAndQFPools(uint256 _treasuryAmount, uint256 _qFPoolAmount);
    event Withdrawed(uint256 _amount, address indexed _address);

    error GrantNotExist();
    error TotalIsNotEqual(uint256 _totalCheck, uint256 _cumulativeTotal);

    constructor(address _hypercert, address _defaultToken) {
        hypercert = Hypercert(_hypercert);
        allowedTokens[_defaultToken] = true;
    }

    ///@notice Function to deposit funds into the donation pool
    ///        One address can deposit in batch for multiple grantIds
    function depositFunds(
        uint256[] calldata _grantIds,
        uint256[] calldata  _depositFunds,
        uint256 _cumulativeTotal,
        address _token
    ) external {
        require(_grantIds.length == _depositFunds.length, "Both arrays length not equal");
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

        uint256[] memory roundedFunds = new uint256[](_grantIds.length);
        uint256 latestUnusedId = hypercert.latestUnusedId();
        uint256 decimals = IERC20Decimal(_token).decimals();
        uint256 totalCheck;
        for (uint256 i; i < _grantIds.length; ) {
            if (_grantIds[i] > latestUnusedId) {
                revert GrantNotExist();   // check if grantId exist.
            }
            donationPoolFundsByGrantId[_grantIds[i]] += _depositFunds[i];
            fundsDepositedByAddress[msg.sender][_grantIds[i]] += _depositFunds[i];
            totalCheck += _depositFunds[i];
            roundedFunds[i] = _depositFunds[i] / (10 ** decimals);
            unchecked {
                i++;
            }
        }

        if (totalCheck != _cumulativeTotal) {
            revert TotalIsNotEqual(totalCheck, _cumulativeTotal);
        }

        emit FundsDeposited(
            msg.sender,
            _grantIds,
            _depositFunds,
            _cumulativeTotal
        );
        
        hypercert.mintBatch(msg.sender, _grantIds, roundedFunds, "");
    }

    ///@notice Function to withdraw funds from the donation pool
    ///        Certain portion of funds will be transferred to the Treasury and QF pool
    function withdrawFunds(uint256 _grantId, address _token) external {
        if (_grantId > hypercert.latestUnusedId()) {
            revert GrantNotExist();
        }
        require(hypercert.grantEnded(_grantId), "Round not ended");
        require(hypercert.grantOwner(_grantId) == msg.sender, "Caller not creator");
        require(allowedTokens[_token] == true, "Token is not supported");

        uint256 amountToQFPool = donationPoolFundsByGrantId[_grantId] * precision
                                    * quadraticFundingPoolShare / 100 / precision;
        uint256 amountToTreasury = donationPoolFundsByGrantId[_grantId] * precision
                                    * treasuryShare / 100 / precision;
        quadraticFundingPoolFunds += amountToQFPool;
        treasuryFunds += amountToTreasury;

        uint256 amountToSend = donationPoolFundsByGrantId[_grantId] - amountToQFPool - amountToTreasury;

        bool success = IERC20Decimal(_token).transfer(
            msg.sender,
            amountToSend
        );
        require(success, "Transaction was not successful");

        emit FundsTransferredToTreasuryAndQFPools(amountToTreasury, amountToQFPool);
        emit FundsWithdrawed(_grantId, amountToSend, msg.sender);

        //update the value of funds in the donation pool
        donationPoolFunds -= donationPoolFundsByGrantId[_grantId];
    }

    // =====================================================================================================
    // QF Pool and Treasury withdrawal functions;
    function qFWithdraw(address _token) external {
        require(qFAddress != address(0), "Address not set");
        require(quadraticFundingPoolFunds != 0, "No amount to withdraw");
        require(allowedTokens[_token] == true, "Token is not supported");
        uint256 amount = quadraticFundingPoolFunds;
        quadraticFundingPoolFunds -= amount;

        bool success = IERC20Decimal(_token).transfer(
            qFAddress,
            amount
        );
        require(success, "Transaction was not successful");

        emit Withdrawed(amount, qFAddress);
    }

    function treasuryWithdraw(address _token) external {
        require(treasuryAddress != address(0), "Address not set");
        require(treasuryFunds != 0, "No amount to withdraw");
        require(allowedTokens[_token] == true, "Token is not supported");
        uint256 amount = treasuryFunds;
        treasuryFunds -= amount;

        bool success = IERC20Decimal(_token).transfer(
            treasuryAddress,
            amount
        );
        require(success, "Transaction was not successful");

        emit Withdrawed(amount, treasuryAddress);
    }

    // =====================================================================================================
    // Owner functions
    function allowToken(address _token) external onlyOwner {
        allowedTokens[_token] = true;
    }

    function setHypercertAddress(Hypercert _hypercertAddress) external onlyOwner {
        hypercert = _hypercertAddress;
    }

    function setQFAddress(address _qFAddress) external onlyOwner {
        qFAddress = _qFAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        treasuryAddress = _treasuryAddress;
    }

    function setQFPoolShare(uint256 _percent) external onlyOwner {
        require(_percent + treasuryShare < 101, "Unavailable percentage");
        quadraticFundingPoolShare = _percent;
    }

    function setTreasuryPoolShare(uint256 _percent) external onlyOwner {
        require(_percent + quadraticFundingPoolShare < 101, "Unavailable percentage");
        quadraticFundingPoolShare = _percent;
    }
}
