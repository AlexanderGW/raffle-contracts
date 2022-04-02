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
    uint number;

    /**
     * @dev Total value of token pot
     */
    uint pot;

    /**
     * @dev Number of players in the current game
     */
    uint playerCount;

    /**
     * @dev Number of all player tickets in the current game
     */
    uint ticketCount;

    /**
     * @dev Maximum number of players allowed in the game
     */
    uint maxPlayers;

    /**
     * @dev Maximum number of tickets per player
     */
    uint maxTicketsPlayer;

    /**
     * @dev Single ticket price
     */
    uint ticketPrice;

    /**
     * @dev Percentage (hundredth) of the pot will go to `gameFeeAddress`.
     * Zero value disables feature
     */
    uint feePercent;

    /**
     * @dev Owner address of the game
     * @todo Allow people to run their own games? Risky?, sure.
     */
    // address ownerAddress;

    /**
     * @dev Destination for the game fee tokens
     */
    address feeAddress;

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
    mapping (address => uint) players;

    /**
     * @dev The game token that players will play for.
     */
    ERC20 token;
  }

  /**
   * @dev Storage for all games (Game structs)
   */
  mapping (uint => Game) games;

  /**
   * @dev Increments with each `_randModulus()` call, for randomness
   */
  uint nonce;

  /**
   * @dev Total number of games (increments in `startGame`)
   */
  uint public totalGames;

  /**
   * @dev Total number of games ended (increments in `endGame`)
   */
  uint public totalGamesEnded;

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
    uint256 pot
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
  function _resetGame(
    uint _gameNumber
  ) private {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status == true,
      "Game ended"
    );

    g.tickets = new address[](0);
    address j;
    for (uint i = 0; i < g.playerCount; i++) {
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
    uint _gameNumber
  ) external onlyRole(MANAGER_ROLE) {
    _resetGame(_gameNumber);
  }

  /**
   * @dev Start a new game (if none running) with given parameters
   */
  function startGame(
    address _gameTokenAddress,
    address _gameFeeAddress,
    uint _gameFeePercent,
    uint _ticketPrice,
    uint _maxPlayers,
    uint _maxTicketsPlayer
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
    uint _gameNumber = totalGames++;

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
    g.token = ERC20(_gameTokenAddress);

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
    uint _gameNumber,
    uint _numberOfTickets
  ) external {
    Game storage g = games[_gameNumber];

    require(
      g.playerCount >= 0,
      "Invalid game"
    );
    require(
      g.status,
      "Game ended"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );

    // Ensure player has enough tokens to play
    uint _totalCost = ABDKMathQuad.toUInt(
      ABDKMathQuad.mul(
        ABDKMathQuad.fromUInt(g.ticketPrice),
        ABDKMathQuad.fromUInt(_numberOfTickets)
      )
    );
    require(
      g.token.allowance(msg.sender, address(this)) >= _totalCost,
      "Insufficent game token allowance"
    );

    // Marker for new player logic
    bool _isNewPlayer = false;

    // Current number of tickets that this player has
    uint _playerTicketCount = g.players[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (g.playerCount == g.maxPlayers) {
        revert("Too many players in game");
      }
      _isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= g.maxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `_totalCost` of `gameToken` from player, this this contract
    _safeTransferFrom(g.token, msg.sender, address(this), _totalCost);

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
    uint _i;
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
    uint _gameNumber
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
    require(
      g.playerCount > 1,
      "Need at least two players in game"
    );

    // Close game
    g.status = false;

    // Pick winner
    uint _rand = _randModulus(100);
    uint _total = g.tickets.length - 1;
    uint _index = _rand % _total;
    g.winnerAddress = g.tickets[_index];

    // Game total pot
    uint _pot = g.pot;

    // Send fees (if applicable)
    if (g.feePercent > 0) {
      uint _feeTotal = ABDKMathQuad.toUInt(
        ABDKMathQuad.mul(
          ABDKMathQuad.div(
            ABDKMathQuad.fromUInt(g.feePercent),
            ABDKMathQuad.fromUInt(100)
          ),
          ABDKMathQuad.fromUInt(_pot)
        )
      );

      // Transfer game fee from pot
      g.token.transfer(g.feeAddress, _feeTotal);

      // Deduct fee from pot value
      _pot = ABDKMathQuad.toUInt(
        ABDKMathQuad.sub(
          ABDKMathQuad.fromUInt(_pot),
          ABDKMathQuad.fromUInt(_feeTotal)
        )
      );
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
      _pot
    );
  }

  /**
   * @dev Return an array of useful game states
   */
  function getGameState(
    uint _gameNumber
  ) external view
  returns (
    bool status,
    uint pot,
    uint playerCount,
    uint ticketCount,
    uint maxPlayers,
    uint maxTicketsPlayer,
    uint ticketPrice,
    uint feePercent,
    address feeAddress,
    address tokenAddress,
    address winnerAddress
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
      g.winnerAddress
    );
  }

  /**
   * @dev Return `totalGamesEnded`, the total number of completed games
   */
  // function getTotalGameCount() external view returns(uint256) {
  //   return totalGamesEnded;
  // }

  /**
   * @dev Define new ERC20 `gameToken` with provided `_token`
   */
  function setGameToken(
    uint _gameNumber,
    address _token
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );

    g.tokenAddress = _token;
    g.token = ERC20(_token);

    return true;
  }

  /**
   * @dev Define new game ticket price
   */
  function setTicketPrice(
    uint _gameNumber,
    uint _price
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      _price > 0,
      "Price greater than 0"
    );

    g.ticketPrice = _price;

    return true;
  }

  /**
   * @dev Defines maximum number of unique game players
   */
  function setMaxPlayers(
    uint _gameNumber,
    uint _max
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      _max > 1,
      "Max players greater than 1"
    );

    g.maxPlayers = _max;

    return true;
  }

  /**
   * @dev Defines maximum number of tickets, per unique game player
   */
  function setMaxTicketsPerPlayer(
    uint _gameNumber,
    uint _max
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      _max > 0,
      "Max tickets greater than 0"
    );

    g.maxTicketsPlayer = _max;

    return true;
  }

  /**
   * @dev Defines the game fee percentage (can only be lower than original value)
   */
  function setGameFeePercent(
    uint _gameNumber,
    uint _percent
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      _percent >= 0,
      "Zero or higher"
    );
    if (g.status == true) {
      require(
        _percent <= g.feePercent,
        "Can only be decreased after game start"
      );
    }

    g.feePercent = _percent;

    return true;
  }

  /**
   * @dev Defines an address for the game fee
   */
  function setGameFeeAddress(
    uint _gameNumber,
    address _address
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );

    g.feeAddress = _address;

    return true;
  }

  /**
   * @dev Returns a random seed
   */
  function _randModulus(
    uint mod
  ) internal returns(uint) {
    uint _rand = uint(
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