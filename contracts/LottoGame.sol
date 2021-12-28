// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './LottoToken.sol';
import './Oracle.sol';

contract LottoGame is AccessControl {

  // Is game running?
  bool public gameState;

  // Increments with each `_randModulus()` call, for randomness 
  uint nonce;

  // Number of completed games
  uint public gameComplete;
  uint public gamePlayerCount;
  uint public gameMaxPlayers;
  uint public gameMaxTicketsPlayer;
  uint public gameTicketPrice;

  address public gameLastWinner;
  address public gameTokenAddress;
  address[] public gameTickets;
  address[] public gamePlayersIndex;
  
  mapping(address => uint) public gamePlayers;

  // The game token that players will play for.
  ERC20 gameToken;
  
  // Randomness oracle, for selecting a winner on `endGame()`
  Oracle oracle;

  // Roles
  bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  constructor(address _oracleAddress) {

    // Random oracle
    oracle = Oracle(_oracleAddress);

    // Grant the contract deployer the default admin role: it will be able
    // to grant and revoke any roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER_ROLE, msg.sender);
    _setupRole(CALLER_ROLE, msg.sender);
  }

  function _safeTransferFrom(
    IERC20 token,
    address sender,
    address recipient,
    uint amount
  ) private {
    bool sent = token.transferFrom(sender, recipient, amount);
    require(sent, "Token transfer failed");
  }

  function resetGame() public onlyRole(CALLER_ROLE) {
    _resetGame();
  }

  function _resetGame() private {
    gameTickets = new address[](0);
    uint _gamePlayerCount = gamePlayerCount;
    address[] memory _gamePlayersIndex = gamePlayersIndex;
    address j;
    for (uint i = 0; i < _gamePlayerCount; i++) {
      j = _gamePlayersIndex[i];
      delete gamePlayers[j];
    }
    gamePlayersIndex = new address[](0);
  }

  function startGame(
    address _token,
    uint _ticketPrice,
    uint _maxPlayers,
    uint _maxTicketsPlayer
  ) public onlyRole(CALLER_ROLE) {
    require(
      gameState == false,
      "Game already started"
    );
    
    gameState = true;
    gamePlayerCount = 0;

    gameTokenAddress = _token;
    gameToken = ERC20(gameTokenAddress);

    gameMaxPlayers = _maxPlayers;
    gameTicketPrice = _ticketPrice;
    gameMaxTicketsPlayer = _maxTicketsPlayer;
  }

  function buyTicket(uint _numberOfTickets) public {
    require(
      gameState == true,
      "Game not started"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );

    uint totalPrice = uint(gameTicketPrice * _numberOfTickets);
    require(
      gameToken.allowance(msg.sender, address(this)) >= totalPrice,
      "Insufficent game token allowance"
    );

    bool isNewPlayer = false;
    uint _playerTicketCount = gamePlayers[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (gamePlayerCount == gameMaxPlayers) {
        revert("Too many players in game");
      }
      isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= gameMaxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `totalPrice` of `gameToken` from player, this this contract
    _safeTransferFrom(gameToken, msg.sender, address(this), totalPrice);

    // If a new player (currently has no tickets)
    if (isNewPlayer) {
      
      // Increase game total player count
      gamePlayerCount++;

      // Used for iteration on game player mapping, when resetting game
      gamePlayersIndex.push(msg.sender);
    }

    // Update number of tickets purchased by player
    gamePlayers[msg.sender] = _playerTicketNextCount;

    uint i;
    while (i != _numberOfTickets) {
      gameTickets.push(msg.sender);
      i++;
    }
  }

  function endGame() public onlyRole(CALLER_ROLE) {
    require(
      gameState == true,
      "Game already ended"
    );
    require(
      gameTickets.length > 1,
      "Need at least two players in game"
    );

    gameState = false;

    uint _rand = _randModulus(100);
    uint _index = _rand % gameTickets.length;
    address _gameLastWinner = gameTickets[_index];

    gameToken.transfer(_gameLastWinner, gameToken.balanceOf(address(this)));

    _resetGame();
	gameLastWinner = _gameLastWinner;
    gameComplete++;
  }

  // function getPlayers() public view returns (address[] memory) {
  //   return gameTickets;
  // }

  function getGameCompleteCount() public view returns(uint) {
    return gameComplete;
  }

  function getGamePlayerCount() public view returns(uint) {
    return gamePlayerCount;
  }

  function getGameToken() public view returns(address) {
    return gameTokenAddress;
  }

  function setGameToken(address _token) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameTokenAddress = _token;
    gameToken = ERC20(gameTokenAddress);
    return true;
  }

  function getTicketPrice() public view returns(uint) {
    return gameTicketPrice;
  }

  function setTicketPrice(uint _price) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameTicketPrice = _price;
    return true;
  }

  function getMaxPlayers() public view returns(uint) {
    return gameMaxPlayers;
  }

  function setMaxPlayers(uint _max) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameMaxPlayers = _max;
    return true;
  }

  function getMaxTicketsPerPlayer() public view returns(uint) {
    return gameMaxTicketsPlayer;
  }

  function setMaxTickets(uint _max) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameMaxTicketsPlayer = _max;
    return true;
  }

  function _randModulus(uint mod) internal returns(uint) {
    uint rand = uint(
      keccak256(
        abi.encodePacked(
          nonce,
          oracle.rand(),
          gameTickets,
          block.timestamp,
          block.difficulty,
          msg.sender
        )
      )
    ) % mod;
    nonce++;
    return rand;
  }
}