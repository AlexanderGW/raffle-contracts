// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameTrophyERC1155 is ERC1155 {
    uint256 public constant TROPHY = 0;

    constructor() ERC1155("http://localhost:3200/GameTrophyERC1155-{id}.jpg") {}

    function awardItem(
        address player
    ) public
    {
        _mint(player, TROPHY, 1, '');
    }
}