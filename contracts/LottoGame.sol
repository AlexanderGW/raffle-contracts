// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';
import './LottoToken.sol';
import './Oracle.sol';

contract LottoGame is AccessControl {

  /**
   * @dev Is game running?
   */
  bool public gameState;

  /**
   * @dev Increments with each `_randModulus()` call, for randomness
   */
  uint nonce;

  /**
   * @dev Number of completed games
   */
  uint public gameCount;

  /**
   * @dev Number of players in the current game
   */
  uint public gamePlayerCount;

  /**
   * @dev Maximum number of players allowed in the game
   */
  uint public gameMaxPlayers;

  /**
   * @dev Maximum number of tickets per player
   */
  uint public gameMaxTicketsPlayer;

  /**
   * @dev Single ticket price
   */
  uint public gameTicketPrice;

  /**
   * @dev Percentage (hundredth) of the pot will go to `gameFeeAddress`.
   * Zero value disables feature
   */
  uint public gameFeePercent = 1;

  /**
   * @dev Destination for the game fee tokens
   */
  address private gameFeeAddress;

  /**
   * @dev Address of the last game pot winner
   */
  address public gameLastWinner;

  /**
   * @dev ERC-20 token address for game tickets
   */
  address public gameTokenAddress;

  /**
   * @dev List of individual player tickets
   */
  address[] public gameTickets;

  /**
   * @dev Cross reference for `gamePlayers` mapping
   */
  address[] public gamePlayersIndex;

  /**
   * @dev List of individual game players
   */
  mapping(address => uint) public gamePlayers;

  /**
   * @dev The game token that players will play for.
   */
  ERC20 gameToken;

  /**
   * @dev Randomness oracle, for selecting a winner on `endGame()`
   */
  Oracle oracle;

  /**
   * @dev Role for `startGame()`, `endGame()`
   */
  bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

  /**
   * @dev Role for `setGameToken()`, `setTicketPrice()`, `setMaxPlayers()`,
   * `setMaxTicketsPerPlayer()`, `setGameFeePercent()`, `setGameFeeAddress()`
   */
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  /**
   * @dev Emitted when a game is started
   */
  event GameStart(
    uint256 indexed _gameId,
    address indexed _gameTokenAddress
  );

  /**
   * @dev Emitted when a game ends, and a player has won
   */
  event GameEnd(
    uint256 indexed _gameId,
    address indexed _gameTokenAddress,
    address indexed _gamePlayer,
    uint256 _value
  );

  /**
   * @dev Setup contract
   */
  constructor(address _oracleAddress) {

    // Random oracle
    oracle = Oracle(_oracleAddress);

    // Grant the contract deployer the default admin role: it will be able
    // to grant and revoke any roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER_ROLE, msg.sender);
    _setupRole(CALLER_ROLE, msg.sender);
  }

  /**
   * @dev Used by `buyTicket()`
   */
  function _safeTransferFrom(
    IERC20 token,
    address sender,
    address recipient,
    uint amount
  ) private {
    bool sent = token.transferFrom(sender, recipient, amount);
    require(sent, "Token transfer failed");
  }

  /**
   * @dev Reset all game storage states
   */
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

  /**
   * @dev Game reset call for managers
   */
  function resetGame() public onlyRole(MANAGER_ROLE) {
    _resetGame();
  }

  /**
   * @dev Start a new game (if none running) with given parameters
   */
  function startGame(
    address _token,
    address _gameFeeAddress,
    uint _gameFeePercent,
    uint _ticketPrice,
    uint _maxPlayers,
    uint _maxTicketsPlayer
  ) public onlyRole(CALLER_ROLE) {
    require(
      gameState == false,
      "Game already started"
    );
    require(
      _ticketPrice > 0,
      "Price greater than 0"
    );
    require(
      _maxPlayers > 1,
      "Max players greater than 1"
    );
    require(
      _maxTicketsPlayer > 0,
      "Max tickets greater than 0"
    );
    
    gameState = true;
    gamePlayerCount = 0;

    gameTokenAddress = _token;
    gameToken = ERC20(gameTokenAddress);

    gameFeeAddress = _gameFeeAddress;
    gameFeePercent = _gameFeePercent;

    gameTicketPrice = _ticketPrice;
    gameMaxPlayers = _maxPlayers;
    gameMaxTicketsPlayer = _maxTicketsPlayer;

    // Fire `GameStart` event
    emit GameStart(
      gameCount,
      gameTokenAddress
    );
  }

  /**
   * @dev Allow a player to buy N ticket(s), at predefined `gameTicketPrice` of `gameToken`
   */
  function buyTicket(uint _numberOfTickets) public {
    require(
      gameState == true,
      "Game not started"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );

    // Ensure player has enough tokens to play
    uint _totalPrice = ABDKMathQuad.toUInt(
      ABDKMathQuad.mul(
        ABDKMathQuad.fromUInt(gameTicketPrice),
        ABDKMathQuad.fromUInt(_numberOfTickets)
      )
    );
    require(
      gameToken.allowance(msg.sender, address(this)) >= _totalPrice,
      "Insufficent game token allowance"
    );

    // Marker for new player logic
    bool _isNewPlayer = false;

    // Current number of tickets that this player has
    uint _playerTicketCount = gamePlayers[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (gamePlayerCount == gameMaxPlayers) {
        revert("Too many players in game");
      }
      _isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= gameMaxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `_totalPrice` of `gameToken` from player, this this contract
    _safeTransferFrom(gameToken, msg.sender, address(this), _totalPrice);

    // If a new player (currently has no tickets)
    if (_isNewPlayer) {
      
      // Increase game total player count
      gamePlayerCount++;

      // Used for iteration on game player mapping, when resetting game
      gamePlayersIndex.push(msg.sender);
    }

    // Update number of tickets purchased by player
    gamePlayers[msg.sender] = _playerTicketNextCount;

    // Add each of the tickets to an array, a random index of this array 
    // will be selected as winner.
    uint _i;
    while (_i != _numberOfTickets) {
      gameTickets.push(msg.sender);
      _i++;
    }
  }

  /**
   * @dev Ends the current game, and picks a winner
   */
  function endGame() public onlyRole(CALLER_ROLE) {
    require(
      gameState == true,
      "Game already ended"
    );
    require(
      gameTickets.length > 1,
      "Need at least two players in game"
    );

    // Close game
    gameState = false;

    // Pick winner
    uint _rand = _randModulus(100);
    uint _total = gameTickets.length - 1;
    uint _index = _rand % _total;
    address _gameLastWinner = gameTickets[_index];

    // Game pot
    uint _pot = gameToken.balanceOf(address(this));

    // Send fees (if applicable)
    if (gameFeePercent > 0) {
      // uint _gameFeePercent = (gameFeePercent / 100);
      // uint _feeTotal = (_gameFeePercent * _pot);
      uint _feeTotal = ABDKMathQuad.toUInt(
        ABDKMathQuad.mul(
          ABDKMathQuad.div(
            ABDKMathQuad.fromUInt(gameFeePercent),
            ABDKMathQuad.fromUInt(100)
          ),
          ABDKMathQuad.fromUInt(_pot)
        )
      );

      // Transfer game fee
      gameToken.transfer(gameFeeAddress, _feeTotal);
      // _pot -= _feeTotal;
      _pot = ABDKMathQuad.toUInt(
        ABDKMathQuad.sub(
          ABDKMathQuad.fromUInt(_pot),
          ABDKMathQuad.fromUInt(_feeTotal)
        )
      );

      // GAS: Recall instead?
      // _pot = gameToken.balanceOf(address(this));
    }

    // Send pot to winner
    gameToken.transfer(_gameLastWinner, _pot);

    // Fire `GameEnd` event
    emit GameEnd(
      gameCount,
      gameTokenAddress,
      _gameLastWinner,
      _pot
    );

    // Prepare for the next game
    _resetGame();
    gameLastWinner = _gameLastWinner;
    gameCount++;
  }

  /**
   * @dev Return `gameState`. Set TRUE by `startGame()`, FALSE by `endGame()`
   */
  function getGameState() public view returns (bool) {
    return gameState;
  }

  /**
   * @dev Return `gameCount`, the total number of completed games
   */
  function getGameCount() public view returns(uint256) {
    return gameCount;
  }

  /**
   * @dev Return `gameLastWinner`, of the last game
   */
  function getGameLastWinner() public view returns(address) {
    return gameLastWinner;
  }

  /**
   * @dev Returns total number of unique game players
   */
  function getGamePlayerCount() public view returns(uint) {
    return gamePlayerCount;
  }

  /**
   * @dev Returns `gameTokenAddress` of current `gameToken`
   */
  function getGameToken() public view returns(address) {
    return gameTokenAddress;
  }

  /**
   * @dev Define new ERC20 `gameToken` with provided `_token`
   */
  function setGameToken(address _token) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameTokenAddress = _token;
    gameToken = ERC20(gameTokenAddress);
    return true;
  }

  /**
   * @dev Returns current game ticket price
   */
  function getTicketPrice() public view returns(uint) {
    return gameTicketPrice;
  }

  /**
   * @dev Define new game ticket price
   */
  function setTicketPrice(uint _price) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      _price > 0,
      "Price greater than 0"
    );
    gameTicketPrice = _price;
    return true;
  }

  /**
   * @dev Returns maximum number of unique game player
   */
  function getMaxPlayers() public view returns(uint) {
    return gameMaxPlayers;
  }

  /**
   * @dev Defines maximum number of unique game players
   */
  function setMaxPlayers(uint _max) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      _max > 1,
      "Max players greater than 1"
    );
    gameMaxPlayers = _max;
    return true;
  }

  /**
   * @dev Returns maximum number of tickets, per unique game player
   */
  function getMaxTicketsPerPlayer() public view returns(uint) {
    return gameMaxTicketsPlayer;
  }

  /**
   * @dev Defines maximum number of tickets, per unique game player
   */
  function setMaxTicketsPerPlayer(uint _max) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      _max > 0,
      "Max tickets greater than 0"
    );
    gameMaxTicketsPlayer = _max;
    return true;
  }

  /**
   * @dev Returns current game fee percentage, deducted from the game pot, called in `endGame`
   */
  function getGameFeePercent() public view returns(uint) {
    return gameFeePercent;
  }

  /**
   * @dev Defines the game fee percentage (can only be lower than original value)
   */
  function setGameFeePercent(uint _percent) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      _percent >= 0,
      "Zero or higher"
    );
    if (gameState == true) {
      require(
        _percent <= gameFeePercent,
        "Can only be decreased after game start"
      );
    }
    gameFeePercent = _percent;
    return true;
  }

  /**
   * @dev Returns the address for the game fee
   */
  function getGameFeeAddress() public view returns(address) {
    return gameFeeAddress;
  }

  /**
   * @dev Defines an address for the game fee
   */
  function setGameFeeAddress(address _address) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    gameFeeAddress = _address;
    return true;
  }

  /**
   * @dev Returns a random seed
   */
  function _randModulus(uint mod) internal returns(uint) {
    uint _rand = uint(
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
    return _rand;
  }
}