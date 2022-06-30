// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Oracle {
  address owner;
  uint256 public rand;

  constructor() {
    owner = msg.sender;
    rand = uint256(
      keccak256(
        abi.encodePacked(
          block.timestamp,
          block.difficulty,
          msg.sender
        )
      )
    );
  }

  function setOwner(address _address) external {
    require(
      msg.sender == owner,
      "Owner only"
    );
    
    owner = _address;
  }

  function feedRandomness(uint256 _rand) external {
    require(
      msg.sender == owner,
      "Owner only"
    );
    
    rand = uint256(
      keccak256(
        abi.encodePacked(
          _rand,
          block.timestamp,
          block.difficulty,
          msg.sender
        )
      )
    );
  }
}