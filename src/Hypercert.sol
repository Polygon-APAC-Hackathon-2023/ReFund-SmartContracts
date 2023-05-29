// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IHypercert.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Hypercert is ERC1155Supply, ERC1155URIStorage, Ownable {
    uint256 public latestUnusedId;
    address public poolAddress;
    string private _baseURI = "";

    mapping(uint256 => GrantInfo) public grantInfo;
    mapping(address => uint256[]) public grantsByAddress;
    mapping(uint256 => uint256) private _totalSupply;
    mapping(uint256 => string) private _tokenURIs;

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
        _onlyPool();
        _;
    }

    // ===========================================================================================================
    // Constructor
    constructor() ERC1155("") {}

    function createGrant(
        string calldata _grantName,
        uint256 _grantEndTime,
        string calldata _tokenURI
    ) external returns (uint256 _grantId) {
        grantInfo[latestUnusedId].grantName = _grantName;
        grantInfo[latestUnusedId].grantEndTime = _grantEndTime;
        grantInfo[latestUnusedId].grantOwner = msg.sender;
        grantInfo[latestUnusedId].grantURI = _tokenURI;
        grantsByAddress[msg.sender].push(latestUnusedId);

        _setURI(latestUnusedId, _tokenURI);

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
        }
        _mintBatch(to, ids, amounts, data);
    }

    // ===========================================================================================================
    // View functions
    function grantOwner(uint256 _grandId) external view returns (address _creator) {
        return grantInfo[_grandId].grantOwner;
    }

    function grantEndTime(uint256 _grandId) external view returns (uint256 _endTime) {
        return grantInfo[_grandId].grantEndTime;
    }

    function grantEnded(uint256 _grandId) external view returns (bool _ended) {
        return grantInfo[_grandId].grantEndTime < block.timestamp;
    }

    function grantsCreatedByAddress(address _addr) external view returns (uint256[] memory _grants) {
        return grantsByAddress[_addr];
    }

    // ===========================================================================================================
    // Owner functions
    function setPool(address _poolAddress) external onlyOwner {
        poolAddress = _poolAddress;
    }

    function setURI(uint256 _tokenId, string calldata _tokenURI) external onlyOwner {
        _setURI(_tokenId, _tokenURI);
    }

    // ===========================================================================================================
    // Internal functions
    function _onlyPool() internal view virtual {
        require(msg.sender == poolAddress, "Funding Pool only function");
    }

    // ===========================================================================================================
    // Override functions
    function uri(uint256 tokenId) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenURI)) : super.uri(tokenId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];
                uint256 supply = _totalSupply[id];
                require(supply >= amount, "ERC1155: burn amount exceeds totalSupply");
                unchecked {
                    _totalSupply[id] = supply - amount;
                }
            }
        }
    }
}
