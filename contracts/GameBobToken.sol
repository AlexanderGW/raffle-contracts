// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract GameBobToken is ERC20, AccessControl {
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  constructor(address _treasury) ERC20("GameBobToken", "GBT") {
    // Grant the contract deployer the default admin role: it will be able
    // to grant and revoke any roles
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(ADMIN_ROLE, msg.sender);

    uint256 _amount = 1000000000 * (10 ** 18);

    _mint(_treasury, _amount);
  }

  function mint(address to, uint256 amount) public onlyRole(ADMIN_ROLE) {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public onlyRole(ADMIN_ROLE) {
    _burn(from, amount);
  }
}