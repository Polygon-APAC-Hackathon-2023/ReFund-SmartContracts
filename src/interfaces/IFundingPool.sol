// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IHypercert.sol";

struct FundInfo {
	uint256 grantId;
	uint256 depositFund;
	string tokenSymbol;
}

interface IFundingPool {

    function depositFunds(
        uint256[] calldata _grantIds,
        uint256[] calldata  _depositFunds,
        uint256 _cumulativeTotal,
        address _token
    ) external;

	function withdrawFunds(uint256 _grantId, address _token) external;

	function fundInfoByAddress(address _addr) external view returns (FundInfo[] memory _fundInfo);
	
	function qFWithdraw(address _token) external returns (uint256 amount);

	function treasuryWithdraw(address _token) external returns (uint256 amount) ;

	function allowToken(address _token, bool _bool) external;

    function setHypercertAddress(IHypercert _hypercertAddress) external;

    function setQFAddress(address _qFAddress) external;

    function setTreasuryAddress(address _treasuryAddress) external;

    function setQFPoolShare(uint256 _percent) external;

    function setTreasuryPoolShare(uint256 _percent) external;

	function uri(uint256 tokenId) external view returns (string memory);

	function donatedAddressNumber(uint256 _id) external view returns (uint256 numbers);

	function quadraticFundingPoolFunds(address _addr) external view returns (uint256 amounts);

	function allowedTokens(address _addr) external view returns (bool _bool);
}