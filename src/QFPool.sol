// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IHypercert.sol";
import "./interfaces/IFundingPool.sol";
import "./interfaces/IERC20Decimal.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract QFPool is Ownable {
	IFundingPool public fundingPool;
	IHypercert public hypercert;
	uint256 public lastStartingId;
	uint256 public timeFrame = 2592000; // one month availability for grant to receive QF.
	uint256 private constant precision = 10 ** 4; // precision for double decimals percentage.

	mapping(address => uint256) public thisBalances;
	mapping(uint256 => mapping(address => uint256)) public allotmentsByIdToken;

	event NewBalance(uint256 _thisBalances, address _token);
	event FundsWithdrawed(uint256 _grantId, uint256 _amount, address _token, address _msgSender);

	error TransferFailed();
	error GrantNotExist();

	constructor(IFundingPool _fundingPool, IHypercert _hypercert) {
		fundingPool = _fundingPool;
		hypercert = _hypercert;
	}

	function distributeFunds(address _token) external {
		withdrawFromFundingPool(_token);
		uint256 latestUnusedId = hypercert.latestUnusedId();
		uint256 totalParticipants = _getTotalParticipants(latestUnusedId);
		uint256 i = lastStartingId;
		uint256 totalToDistribute = thisBalances[_token];
		while (i < latestUnusedId) {
			unchecked {
				uint256 allotment = fundingPool.donatedAddressNumber(i) * precision / totalParticipants;
				uint256 amount = allotment * totalToDistribute / precision;
				allotmentsByIdToken[i][_token] += amount;
				i++;
			}
		}
	}

	function withdrawFromFundingPool(address _token) public {
		if (fundingPool.quadraticFundingPoolFunds(_token) > 0) {
			thisBalances[_token] += fundingPool.qFWithdraw(_token);
		}

		emit NewBalance(thisBalances[_token], _token);
	}

	function _getTotalParticipants(uint256 latestUnusedId) internal returns (uint256 totalParticipants) {
		uint256 i = lastStartingId;
		while (i < latestUnusedId) {
			uint256 endTime = hypercert.grantEndTime(i);
			if (block.timestamp < endTime + timeFrame) break;
			unchecked {
				i++;
			}
		}
		lastStartingId = i;
		while (i < latestUnusedId) {
			totalParticipants += fundingPool.donatedAddressNumber(i);
			unchecked {
				i++;
			}
		}
	}

    function withdrawFunds(uint256 _grantId, address _token) external {
        if (_grantId >= hypercert.latestUnusedId()) revert GrantNotExist();
        require(hypercert.grantOwner(_grantId) == msg.sender, "Caller not creator");
        require(fundingPool.allowedTokens(_token) == true, "Token is not supported");
		require(allotmentsByIdToken[_grantId][_token] > 0, "No Balance to withdraw");

        uint256 amount = allotmentsByIdToken[_grantId][_token];
		allotmentsByIdToken[_grantId][_token] = 0;
        if (!IERC20Decimal(_token).transfer(msg.sender, amount)) revert TransferFailed();

        emit FundsWithdrawed(_grantId, amount, _token, msg.sender);
    }

    // =====================================================================================================
    // Owner functions
    function setHypercertAddress(IHypercert _hypercert) external onlyOwner {
        hypercert = _hypercert;
    }

    function setFundingPoolAddress(IFundingPool _fundingPool) external onlyOwner {
        fundingPool = _fundingPool;
    }
}