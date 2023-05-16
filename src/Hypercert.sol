// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Hypercert is ERC1155Supply, Ownable {
    uint256 public latestUnusedId;
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

    error RoundEnded(uint256 _grantId);

    // ===========================================================================================================
    // Modifiers
    modifier onlyPool() {
        require(msg.sender == poolAddress, "Funding Pool only function");
        _;
    }

    // ===========================================================================================================
    // Constructor
    constructor(string memory uri_) ERC1155(uri_) {}

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

    // @Notice only Pool can mint.
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyPool {
        for (uint256 i; i < ids.length; ) {
            if (block.timestamp > grantInfo[ids[i]].grantEndTime) {
                revert RoundEnded(ids[i]);
            }
            unchecked {
                i++;
            }
        _mintBatch(to, ids, amounts, data);
        }
    }

    // ===========================================================================================================
    // View functions
    function grantOwner(uint256 _grandId) external view returns (address _creator) {
        return grantInfo[_grandId].grantOwner;
    }

    function grantEnded(uint256 _grandId) external view returns (bool _ended) {
        return grantInfo[_grandId].grantEndTime > block.timestamp;
    }

    // ===========================================================================================================
    // Owner functions
    function setPool(address _poolAddress) external onlyOwner {
        poolAddress = _poolAddress;
    }

    function setURI(string calldata _newuri) external onlyOwner {
        _setURI(_newuri);
    }
}
