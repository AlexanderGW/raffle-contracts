// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import './Oracle.sol';

contract GameMaster is AccessControl {
  using SafeMath for uint256;

  /**
   * @dev Game record struct
   */
  struct Game {

    /**
     * @dev Is game running?
     */
    bool status;

    /**
     * @dev Number assigned to the game (sequental, based on total games)
     */
    uint256 number;

    /**
     * @dev Total value of token pot
     */
    uint256 pot;

    /**
     * @dev Number of players in the current game
     */
    uint256 playerCount;

    /**
     * @dev Number of all player tickets in the current game
     */
    uint256 ticketCount;

    /**
     * @dev Maximum number of players allowed in the game
     */
    uint256 maxPlayers;

    /**
     * @dev Maximum number of tickets per player
     */
    uint256 maxTicketsPlayer;

    /**
     * @dev Single ticket price
     */
    uint256 ticketPrice;

    /**
     * @dev Percentage (hundredth) of the pot will go to `gameFeeAddress`.
     * Zero value disables feature
     */
    uint256 feePercent;

    /**
     * @dev Owner address of the game
     * @todo Allow people to run their own games? Risky?, sure.
     */
    // address ownerAddress;

    /**
     * @dev Winner result (i.e. single ticket index for raffle, or multiple numbers for lotto)
     */
    uint256[] winnerResult;

    /**
     * @dev Destination for the game fee tokens
     */
    address feeAddress;

    /**
     * @dev Game address for underlying functionality (raffle, lotto, ...)
     */
    address gameAddress;

    /**
     * @dev ERC-20 token address for game tickets
     */
    address tokenAddress;

    /**
     * @dev Address of the game winner
     */
    address winnerAddress;

    /**
     * @dev List of individual player tickets
     */
    address[] tickets;

    /**
     * @dev Cross reference for `Game` struct `players` mapping
     */
    address[] playersIndex;

    /**
     * @dev List of unique game players
     */
    mapping (address => uint256) players;

    /**
     * @dev The game token that players will play for.
     */
    IERC20Metadata token;

    /**
     * @dev The game interface.
     * @todo Modular game interface (lotto, raffle, ...)
     */
    // IGB game;
  }

  /**
   * @dev Storage for all games (`Game` structs)
   */
  mapping (uint256 => Game) games;

  /**
   * @dev Increments with each `_randModulus()` call, for randomness
   */
  uint256 nonce;

  /**
   * @dev Total number of games (increments in `startGame`)
   */
  uint256 public totalGames;

  /**
   * @dev Total number of games ended (increments in `endGame`)
   */
  uint256 public totalGamesEnded;

  /**
   * @dev Randomness oracle, for selecting winning number(s) on `endGame()`
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
  event GameStarted(
    address indexed tokenAddress,
    address indexed feeAddress,
    uint256 indexed gameNumber,
    uint256 feePercent,
    uint256 ticketPrice,
    uint256 maxPlayers,
    uint256 maxTicketsPlayer
  );

  /**
   * @dev Emitted when a game's parameters are changed
   */
  event GameChanged(
    uint256 indexed gameNumber
  );

  /**
   * @dev Emitted when a player buys ticket(s)
   */
  event TicketBought(
    address indexed playerAddress,
    uint256 indexed gameNumber,
    uint256 playerCount,
    uint256 ticketCount
  );

  /**
   * @dev Emitted when a game ends, and a player has won
   */
  event GameEnded(
    address indexed tokenAddress,
    address indexed winnerAddress,
    uint256 indexed gameNumber,
    uint256[] winnerResult,
    uint256 pot
  );

  /**
   * @dev Setup contract
   */
  constructor(
    address _oracleAddress
  ) {

    // Oracle of randomness
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
    IERC20Metadata token,
    address sender,
    address recipient,
    uint256 amount
  ) private {
    bool sent = token.transferFrom(sender, recipient, amount);
    require(sent, "Token transfer failed");
  }

  /**
   * @dev Reset all game storage states
   */
  function _resetGame(
    uint256 _gameNumber
  ) private {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );

    g.tickets = new address[](0);
    address j;
    for (uint256 i = 0; i < g.playerCount; i++) {
      j = g.playersIndex[i];
      delete g.players[j];
    }
    g.playersIndex = new address[](0);
    g.playerCount = 0;
    g.ticketCount = 0;
  }

  /**
   * @dev Game reset call for managers
   */
  function resetGame(
    uint256 _gameNumber
  ) external onlyRole(MANAGER_ROLE) {
    _resetGame(_gameNumber);
  }

  /**
   * @dev Start a new game (if none running) with given parameters
   */
  function startGame(
    address _gameTokenAddress,
    address _gameFeeAddress,
    uint256 _gameFeePercent,
    uint256 _ticketPrice,
    uint256 _maxPlayers,
    uint256 _maxTicketsPlayer
  ) external onlyRole(CALLER_ROLE) {
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

    // Get game number
    uint256 _gameNumber = totalGames++;

    // Create new game record
    Game storage g = games[_gameNumber];
    g.status = true;
    g.number = _gameNumber;
    g.playerCount = 0;
    g.ticketCount = 0;
    g.maxPlayers = _maxPlayers;
    g.maxTicketsPlayer = _maxTicketsPlayer;
    g.ticketPrice = _ticketPrice;
    g.feePercent = _gameFeePercent;
    g.feeAddress = _gameFeeAddress;
    g.tokenAddress = _gameTokenAddress;
    g.token = IERC20Metadata(_gameTokenAddress);

    // Fire `GameStarted` event
    emit GameStarted(
      g.tokenAddress,
      g.feeAddress,
      g.number,
      g.feePercent,
      g.ticketPrice,
      g.maxPlayers,
      g.maxTicketsPlayer
    );
  }

  /**
   * @dev Allow a player to buy Nth tickets in `_gameNumber`, at predefined `g.ticketPrice` of `g.token`
   */
  function buyTicket(
    uint256 _gameNumber,
    uint256 _numberOfTickets
  ) external {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers >= 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );

    // Ensure player has enough tokens to play
    uint256 _totalCost = g.ticketPrice.mul(_numberOfTickets);
    require(
      g.token.allowance(msg.sender, address(this)) >= _totalCost,
      "Insufficent game token allowance"
    );

    // Marker for new player logic
    bool _isNewPlayer = false;

    // Current number of tickets that this player has
    uint256 _playerTicketCount = g.players[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (g.playerCount == g.maxPlayers) {
        revert("Too many players in game");
      }
      _isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint256 _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= g.maxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `_totalCost` of `gameToken` from player, this this contract
    // g.token.transferFrom(msg.sender, address(this), _totalCost);
    _safeTransferFrom(
      g.token,
      msg.sender,
      address(this),
      _totalCost
    );

    // Add total ticket cost to pot
    g.pot += _totalCost;

    // If a new player (currently has no tickets)
    if (_isNewPlayer) {

      // Increase game total player count
      g.playerCount++;

      // Used for iteration on game player mapping, when resetting game
      g.playersIndex.push(msg.sender);
    }

    // Update number of tickets purchased by player
    g.players[msg.sender] = _playerTicketNextCount;

    // Add each of the tickets to an array, a random index of this array 
    // will be selected as winner.
    uint256 _i;
    while (_i != _numberOfTickets) {
      g.tickets.push(msg.sender);
      _i++;
    }

    // Increase total number of game player tickets
    g.ticketCount += _numberOfTickets;

    // Fire `TicketBought` event
    emit TicketBought(
      msg.sender,
      g.number,
      g.playerCount,
      g.ticketCount
    );
  }

  /**
   * @dev Ends the current game, and picks a winner
   */
  function endGame(
    uint256 _gameNumber
  ) external onlyRole(CALLER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );

    uint256 _pot = g.pot;
    uint256 _balance = g.token.balanceOf(address(this));
    require(
      g.pot <= _balance,
      "Not enough of game token in reserve"
    );

    // Close game
    g.status = false;

    // Pick winner
    uint256 _rand = _randModulus(100);
    uint256 _total = g.ticketCount - 1;
    uint256 _index = (_total == 0) ? 0 : (_rand % _total);

    // Store winner result index
    g.winnerResult.push(_index);

    // Store winner address index
    g.winnerAddress = g.tickets[_index];

    // Send fees (if applicable)
    if (g.feePercent > 0) {
      uint256 _feeTotal = _pot.div(100).mul(g.feePercent);

      // Transfer game fee from pot
      if (_feeTotal > 0) {
        g.token.transfer(g.feeAddress, _feeTotal);

        // Deduct fee from pot value
        _pot -= _feeTotal;
      }
    }

    // Send pot to winner
    g.token.transfer(g.winnerAddress, _pot);

    // @todo Trim superfluous game data for gas saving
    totalGamesEnded++;

    // Fire `GameEnded` event
    emit GameEnded(
      g.tokenAddress,
      g.winnerAddress,
      g.number,
      g.winnerResult,
      _pot
    );
  }

  /**
   * @dev Return an array of useful game states
   */
  function getGameState(
    uint256 _gameNumber
  ) external view
  returns (
    bool status,
    uint256 pot,
    uint256 playerCount,
    uint256 ticketCount,
    uint256 maxPlayers,
    uint256 maxTicketsPlayer,
    uint256 ticketPrice,
    uint256 feePercent,
    address feeAddress,
    address tokenAddress,
    address winnerAddress,
    uint256[] memory winnerResult
  ) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );

    return (
      g.status,
      g.pot,
      g.playerCount,
      g.ticketCount,
      g.maxPlayers,
      g.maxTicketsPlayer,
      g.ticketPrice,
      g.feePercent,
      g.feeAddress,
      g.tokenAddress,
      g.winnerAddress,
      g.winnerResult
    );
  }

  /**
   * @dev Define new ERC20 `gameToken` with provided `_token`
   */
  function setGameToken(
    uint256 _gameNumber,
    address _token
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );

    g.tokenAddress = _token;
    g.token = IERC20Metadata(_token);

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Define new game ticket price
   */
  function setTicketPrice(
    uint256 _gameNumber,
    uint256 _price
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );
    require(
      _price > 0,
      "Price greater than 0"
    );

    g.ticketPrice = _price;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Defines maximum number of unique game players
   */
  function setMaxPlayers(
    uint256 _gameNumber,
    uint256 _max
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );
    require(
      _max > 1,
      "Max players greater than 1"
    );

    g.maxPlayers = _max;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Defines maximum number of tickets, per unique game player
   */
  function setMaxTicketsPerPlayer(
    uint256 _gameNumber,
    uint256 _max
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );
    require(
      _max > 0,
      "Max tickets greater than 0"
    );

    g.maxTicketsPlayer = _max;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Defines the game fee percentage (can only be lower than original value)
   */
  function setGameFeePercent(
    uint256 _gameNumber,
    uint256 _percent
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );
    require(
      _percent >= 0,
      "Zero or higher"
    );
    require(
      _percent < g.feePercent,
      "Can only be decreased after game start"
    );

    g.feePercent = _percent;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Defines an address for the game fee
   */
  function setGameFeeAddress(
    uint256 _gameNumber,
    address _address
  ) external onlyRole(MANAGER_ROLE) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game already ended"
    );

    g.feeAddress = _address;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Returns a random seed
   */
  function _randModulus(
    uint256 mod
  ) internal returns(uint256) {
    uint256 _rand = uint256(
      keccak256(
        abi.encodePacked(
          nonce,
          oracle.rand(),
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