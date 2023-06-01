// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IHypercert.sol";
import "./interfaces/IFundingPool.sol";
import "./interfaces/IERC20Decimal.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


/// @title FundingPool
/// @dev This is the contract that will handle operations related to Donation Pool and QF Pool
contract FundingPool is Ownable {
    IHypercert public hypercert;
    address public treasuryAddress;
    address public qFAddress;
    uint256 public donationPoolFunds;
    uint256 public treasuryShare = 2; // 2%
    uint256 public quadraticFundingPoolShare = 3; // 3%
    uint256 private constant precision = 10 ** 2; // precision made for percentage

    mapping(address => bool) public allowedTokens;
    mapping(uint256 => mapping(address => uint256)) public donationPoolFundsByGrantId;
    mapping(address => FundInfo[]) public fundsDepositedByAddress;
    mapping(address => uint256) public quadraticFundingPoolFunds;
    mapping(address => uint256) public treasuryFunds;
    mapping(uint256 => address[]) public donatedAddresses;
    mapping(uint256 => uint256) public donatedAddressNumber;
    mapping(address => bool) public addressCounted;

    event FundsDeposited(
        address indexed _from,
        uint256[] _grantId,
        uint256[] _value,
        uint256 _cumulativeTotal
    );
    event FundsWithdrawed(uint256 indexed _grantId, uint256 _amount, address indexed _grantCreator);
    event FundsTransferredToTreasuryAndQFPools(uint256 _treasuryAmount, uint256 _qFPoolAmount);
    event Withdrawed(uint256 _amount, address indexed _address);

    error GrantNotExist();
    error TotalIsNotEqual(uint256 _totalCheck, uint256 _cumulativeTotal);

    modifier onlyQF() {
        require(msg.sender == qFAddress, "Not QF address");
        _;
    }
    
    modifier onlyTreasury() {
        require(msg.sender == treasuryAddress, "Not Treasury address");
        _;
    }

    constructor(address _hypercert, address _defaultToken) {
        hypercert = IHypercert(_hypercert);
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

        uint256[] memory roundedFunds = __depositFunds(_grantIds, _depositFunds, _cumulativeTotal, _token);

        emit FundsDeposited(
            msg.sender,
            _grantIds,
            _depositFunds,
            _cumulativeTotal
        );
        
        hypercert.mintBatch(msg.sender, _grantIds, roundedFunds, "");
    }

    function __depositFunds(
        uint256[] calldata _grantIds,
        uint256[] calldata  _depositFunds,
        uint256 _cumulativeTotal,
        address _token
    ) internal returns (uint256[] memory roundedFunds) {
        donationPoolFunds += _cumulativeTotal;

        roundedFunds = new uint256[](_grantIds.length);
        uint256 latestUnusedId = hypercert.latestUnusedId();
        uint256 decimals = IERC20Decimal(_token).decimals();
        string memory _tokenSymbol = IERC20Decimal(_token).symbol();
        uint256 totalCheck;
        for (uint256 i; i < _grantIds.length; ) {
            if (_grantIds[i] >= latestUnusedId) revert GrantNotExist();   // check if grantId exist.
            donationPoolFundsByGrantId[_grantIds[i]][_token] += _depositFunds[i];

            fundsDepositedByAddress[msg.sender].push(FundInfo(
                _grantIds[i],
                _depositFunds[i],
                _tokenSymbol
            ));

            unchecked {      // overflows and underflows not possible in below operations
            if (addressCounted[msg.sender] == false) {
                donatedAddresses[_grantIds[i]].push(msg.sender);
                donatedAddressNumber[_grantIds[i]] += 1;
                addressCounted[msg.sender] == true;
            }
            totalCheck += _depositFunds[i];
            roundedFunds[i] = _depositFunds[i] / (10 ** decimals);
                i++;
            }
        }

        if (totalCheck != _cumulativeTotal) {
            revert TotalIsNotEqual(totalCheck, _cumulativeTotal);
        }
    }

    /** @notice Function to withdraw funds from the donation pool
     *  Certain portion of funds will be transferred to the Treasury and QF pool
     *  Anyone can call this but funds will only transfer to grant owner.
     */
    function withdrawFunds(uint256 _grantId, address _token) external {
        if (_grantId >= hypercert.latestUnusedId()) {
            revert GrantNotExist();
        }
        require(hypercert.grantEnded(_grantId), "Round not ended");
        require(allowedTokens[_token] == true, "Token is not supported");
        require(donationPoolFundsByGrantId[_grantId][_token] > 0, "No amount to withdraw");

        uint256 amountToQFPool = donationPoolFundsByGrantId[_grantId][_token] * precision
                                    * quadraticFundingPoolShare / 100 / precision;
        uint256 amountToTreasury = donationPoolFundsByGrantId[_grantId][_token] * precision
                                    * treasuryShare / 100 / precision;
        
        // overflows and underflows not possible
        uint256 amountToSend;
        unchecked {
            quadraticFundingPoolFunds[_token] += amountToQFPool;
            treasuryFunds[_token] += amountToTreasury;
            amountToSend = donationPoolFundsByGrantId[_grantId][_token] - amountToQFPool - amountToTreasury;

            //update the value of funds in the donation pool
            donationPoolFunds -= donationPoolFundsByGrantId[_grantId][_token];
            donationPoolFundsByGrantId[_grantId][_token] = 0;
        }

        address grantCreator = hypercert.grantOwner(_grantId);
        bool success = IERC20Decimal(_token).transfer(
            grantCreator,
            amountToSend
        );
        require(success, "Transaction was not successful");

        emit FundsTransferredToTreasuryAndQFPools(amountToTreasury, amountToQFPool);
        emit FundsWithdrawed(_grantId, amountToSend, grantCreator);
    }

    // =====================================================================================================
    // View functions
    function fundInfoByAddress(address _addr) external view returns (FundInfo[] memory _fundInfo) {
        return fundsDepositedByAddress[_addr];
    }

    // =====================================================================================================
    // QF Pool and Treasury withdrawal functions
    function qFWithdraw(address _token) external onlyQF returns (uint256 amount) {
        require(qFAddress != address(0), "Address not set");
        require(quadraticFundingPoolFunds[_token] != 0, "No amount to withdraw");
        require(allowedTokens[_token] == true, "Token is not supported");
        amount = quadraticFundingPoolFunds[_token];
        quadraticFundingPoolFunds[_token] -= amount;

        bool success = IERC20Decimal(_token).transfer(
            qFAddress,
            amount
        );
        require(success, "Transaction was not successful");

        emit Withdrawed(amount, qFAddress);
    }

    function treasuryWithdraw(address _token) external onlyTreasury returns (uint256 amount) {
        require(treasuryAddress != address(0), "Address not set");
        require(treasuryFunds[_token] != 0, "No amount to withdraw");
        require(allowedTokens[_token] == true, "Token is not supported");
        amount = treasuryFunds[_token];
        treasuryFunds[_token] -= amount;

        bool success = IERC20Decimal(_token).transfer(
            treasuryAddress,
            amount
        );
        require(success, "Transaction was not successful");

        emit Withdrawed(amount, treasuryAddress);
    }

    // =====================================================================================================
    // Owner functions
    function allowToken(address _token, bool _bool) external onlyOwner {
        allowedTokens[_token] = _bool;
    }

    function setHypercertAddress(IHypercert _hypercertAddress) external onlyOwner {
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
