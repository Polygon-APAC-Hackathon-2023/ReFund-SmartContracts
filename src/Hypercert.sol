// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Hypercert is ERC1155 {
	uint256 public mintEndTime;

    constructor(string memory uri_, uint256 _mintEndTime) {
        _setURI(uri_);
		mintEndTime = _mintEndTime;
    }

	// will change to internal so only Pool.sol can call mint
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
		require(block.timestamp < mintEndTime, "Round ended");
		_mint(to, id, amount, data);
    }
}