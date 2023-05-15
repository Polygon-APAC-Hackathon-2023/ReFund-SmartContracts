// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

contract Hypercert is ERC1155 {
	uint256 public latestUnusedId;

    struct GrantInfo {
        string grantName;
        uint256 grantEndTime;
        address grantOwner;
    }

    mapping(uint256 => GrantInfo) public grantInfo;

    event GrantCreated(string _grantName, uint256 indexed _grantId, uint256 _grantEndTime, address indexed _grantOwner);
	event MintEndTime(uint256 _grantId, uint256 _grantEndTime);

    constructor(string memory uri_) ERC1155(uri_){}

    function createGrant(string calldata _grantName, uint256 _grantEndTime) external {
        grantInfo[latestUnusedId].grantName = _grantName;
        grantInfo[latestUnusedId].grantEndTime = _grantEndTime;
        grantInfo[latestUnusedId].grantOwner = msg.sender;
        
        emit GrantCreated(_grantName, latestUnusedId, _grantEndTime, msg.sender);
        latestUnusedId++;
    }

	// will change to only Pool.sol can mint
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
		require(block.timestamp < grantInfo[id].grantEndTime, "Round ended");
		_mint(to, id, amount, data);
    }
}