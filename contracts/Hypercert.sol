// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract Hypercert is ERC1155Supply {
    uint256 public latestUnusedId;
    address public owner;
    address public poolAddress;

    struct GrantInfo {
        string grantName;
        uint256 grantEndTime;
        address grantOwner;
    }

    mapping(uint256 => GrantInfo) public grantInfo;
    mapping(address => uint256[]) public grantsByAddress;

    event GrantCreated(
        string _grantName,
        uint256 indexed _grantId,
        uint256 _grantEndTime,
        address indexed _grantOwner,
        uint256[] _grantsByAddress
    );

    // ===========================================================================================================
    // Modifiers
    modifier onlyPool() {
        require(msg.sender == poolAddress, "Funding Pool only function");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only function");
        _;
    }

    // ===========================================================================================================
    // Constructor
    constructor(string memory uri_) ERC1155(uri_) {
        owner = msg.sender;
    }

    function createGrant(
        string calldata _grantName,
        uint256 _grantEndTime
    ) external returns (uint256 _grantId) {
        grantInfo[latestUnusedId].grantName = _grantName;
        grantInfo[latestUnusedId].grantEndTime = _grantEndTime;
        grantInfo[latestUnusedId].grantOwner = msg.sender;
        grantsByAddress[msg.sender].push(latestUnusedId);

        emit GrantCreated(
            _grantName,
            latestUnusedId,
            _grantEndTime,
            msg.sender,
            grantsByAddress[msg.sender]
        );

        return latestUnusedId++;
    }

    // internal and only FundingPool can mint
    function _mintBatchExternal(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyPool {
        for (uint256 i; i < ids.length; ) {
            require(
                block.timestamp < grantInfo[ids[i]].grantEndTime,
                "Round ended"
            );
            super._mintBatch(to, ids, amounts, data);
            unchecked {
                i++;
            }
        }
    }

    ///@dev Function that checks if a given grant creator exists in the mapping
    function _grantCreatorExists(
        address _grantCreator
    ) public view returns (bool) {
        if (grantsByAddress[_grantCreator].length != 0) {
            return true;
        } else {
            return false;
        }
    }

    ///@dev Function to check that the grant period of tokenID has ended
    function _grantPeriodHasEnded(uint256 _tokenID) public view returns (bool) {
        if (grantInfo[_tokenID].grantEndTime < block.timestamp) {
            return true;
        } else {
            return false;
        }
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {}

    // ===========================================================================================================
    // Owner functions
    function setPool(address _poolAddress) external onlyOwner {
        poolAddress = _poolAddress;
    }

    function setURI(string calldata _newuri) external onlyOwner {
        _setURI(_newuri);
    }
}