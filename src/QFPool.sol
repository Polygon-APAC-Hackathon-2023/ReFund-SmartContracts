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
	event FundsWithdrawed(uint256 _grantId, uint256 _amount, address _token, address _grantCreator);
	event NewTimeFrame(uint256 _timeFrame);

	error TransferFailed();
	error GrantNotExist();

	constructor(address _fundingPool, address _hypercert) {
		fundingPool = IFundingPool(_fundingPool);
		hypercert = IHypercert(_hypercert);
	}

	/**
	 * @notice Distribute funds to eligible grants according to number of contributors over
	 * total contributors within the eligible period.
	 * Eligible means grants ended within timeFrame.
	 */
	function distributeFunds(address _token) public {
		require(fundingPool.allowedTokens(_token) == true, "Token is not supported");
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
		thisBalances[_token] = 0;
	}

	function withdrawFromFundingPool(address _token) public {
		if (fundingPool.quadraticFundingPoolFunds(_token) > 0) {
			thisBalances[_token] += fundingPool.qFWithdraw(_token);
			emit NewBalance(thisBalances[_token], _token);
		}
	}

	/// @notice check if grant ended and still within eligible timeframe.
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

	/// @notice Withdraw allocated funds for grant creator.
    function withdrawFunds(uint256 _grantId, address _token) external {
        if (_grantId >= hypercert.latestUnusedId()) revert GrantNotExist();
		require(allotmentsByIdToken[_grantId][_token] > 0, "No Balance to withdraw");
		require(hypercert.grantEnded(_grantId), "Round not ended");
		if (thisBalances[_token] != 0) distributeFunds(_token);

		address grantCreator = hypercert.grantOwner(_grantId);
        uint256 amount = allotmentsByIdToken[_grantId][_token];
		allotmentsByIdToken[_grantId][_token] = 0;
        if (!IERC20Decimal(_token).transfer(grantCreator, amount)) revert TransferFailed();

        emit FundsWithdrawed(_grantId, amount, _token, grantCreator);
    }

    /// =====================================================================================================
    /// @dev Owner functions
    function setHypercertAddress(IHypercert _hypercert) external onlyOwner {
        hypercert = _hypercert;
    }

    function setFundingPoolAddress(IFundingPool _fundingPool) external onlyOwner {
        fundingPool = _fundingPool;
    }

	function setTimeFrame(uint256 _timeFrame) external onlyOwner {
		timeFrame = _timeFrame;
		emit NewTimeFrame(timeFrame);
	}
}