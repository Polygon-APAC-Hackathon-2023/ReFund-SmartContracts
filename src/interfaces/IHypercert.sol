// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct GrantInfo {
	string grantName;
	uint256 grantEndTime;
	address grantOwner;
	string grantURI;
}

interface IHypercert {

    function createGrant(
        string calldata _grantName,
        uint256 _grantEndTime,
        string calldata _tokenURI
    ) external returns (uint256 _grantId);

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function grantOwner(uint256 _grandId) external view returns (address _creator);

    function grantEnded(uint256 _grandId) external view returns (bool _ended);

    function grantsCreatedByAddress(address _addr) external view returns (uint256[] memory _grants);

    function setPool(address _poolAddress) external;

    function setURI(uint256 _tokenId, string calldata _tokenURI) external;

	function latestUnusedId() external view returns (uint256 _id);

	function grantEndTime(uint256 _grandId) external view returns (uint256 _endTime);
}