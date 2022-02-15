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
     * @dev Destination for the game fee tokens
     */
    address feeAddress;

    /**
     * @dev ERC-20 token address for game tickets
     */
    address tokenAddress;

    /**
     * @dev Address of the last game pot winner
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
    mapping(address => uint) players;

    /**
     * @dev The game token that players will play for.
     */
    ERC20 token;
  }

  /**
   * @dev Mapping of all games (Game structs)
   */
  // Game[] games;
  mapping(uint => Game) games;

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
  event GameStart(
    uint256 indexed _gameNumber,
    address indexed _gameTokenAddress
  );

  /**
   * @dev Emitted when a game ends, and a player has won
   */
  event GameEnd(
    uint256 indexed _gameNumber,
    address indexed _gameTokenAddress,
    address indexed _gameWinnerAddress,
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
  function _resetGame(
    uint _gameNumber
  ) private {
    Game storage game = games[_gameNumber];

    require(
      game.playerCount >= 0,
      "Invalid game"
    );
    require(
      game.status == true,
      "Game ended"
    );

    games[_gameNumber].tickets = new address[](0);
    address j;
    for (uint i = 0; i < game.playerCount; i++) {
      j = game.playersIndex[i];
      delete games[_gameNumber].players[j];
    }
    games[_gameNumber].playersIndex = new address[](0);
    games[_gameNumber].playerCount = 0;
    games[_gameNumber].ticketCount = 0;
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
  ) external onlyRole(CALLER_ROLE)
  returns (uint gameNumber) {
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

    uint _gameNumber = totalGames;

    // Create new game record
    Game storage game = games[_gameNumber];
    game.status = true;
    game.number = _gameNumber;
    game.playerCount = 0;
    game.ticketCount = 0;
    game.maxPlayers = _maxPlayers;
    game.maxTicketsPlayer = _maxTicketsPlayer;
    game.ticketPrice = _ticketPrice;
    game.feePercent = _gameFeePercent;
    game.feeAddress = _gameFeeAddress;
    game.tokenAddress = _gameTokenAddress;
    game.token = ERC20(_gameTokenAddress);

    // Fire `GameStart` event
    emit GameStart(
      _gameNumber,
      _gameTokenAddress
    );

    totalGames++;

    return _gameNumber;
  }

  /**
   * @dev Allow a player to buy Nth tickets in `_gameNumber`, at predefined `game.ticketPrice` of `game.token`
   */
  function buyTicket(
    uint _gameNumber,
    uint _numberOfTickets
  ) external {
    Game storage game = games[_gameNumber];

    require(
      game.playerCount >= 0,
      "Invalid game"
    );
    require(
      game.status == true,
      "Game ended"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );

    // Ensure player has enough tokens to play
    uint _totalPrice = ABDKMathQuad.toUInt(
      ABDKMathQuad.mul(
        ABDKMathQuad.fromUInt(game.ticketPrice),
        ABDKMathQuad.fromUInt(_numberOfTickets)
      )
    );
    require(
      game.token.allowance(msg.sender, address(this)) >= _totalPrice,
      "Insufficent game token allowance"
    );

    // Marker for new player logic
    bool _isNewPlayer = false;

    // Current number of tickets that this player has
    uint _playerTicketCount = game.players[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (game.playerCount == game.maxPlayers) {
        revert("Too many players in game");
      }
      _isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= game.maxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `_totalPrice` of `gameToken` from player, this this contract
    _safeTransferFrom(game.token, msg.sender, address(this), _totalPrice);

    // If a new player (currently has no tickets)
    if (_isNewPlayer) {
      
      // Increase game total player count
      games[_gameNumber].playerCount++;

      // Used for iteration on game player mapping, when resetting game
      games[_gameNumber].playersIndex.push(msg.sender);
    }

    // Update number of tickets purchased by player
    games[_gameNumber].players[msg.sender] = _playerTicketNextCount;

    // Add each of the tickets to an array, a random index of this array 
    // will be selected as winner.
    uint _i;
    while (_i != _numberOfTickets) {
      games[_gameNumber].tickets.push(msg.sender);
      _i++;
    }

    // Increase total number of game player tickets
    games[_gameNumber].ticketCount += _numberOfTickets;
  }

  /**
   * @dev Ends the current game, and picks a winner
   */
  function endGame(
    uint _gameNumber
  ) external onlyRole(CALLER_ROLE) {
    Game storage game = games[_gameNumber];

    require(
      game.playerCount >= 0,
      "Invalid game"
    );
    require(
      game.status == true,
      "Game already ended"
    );
    require(
      game.playerCount > 1,
      "Need at least two players in game"
    );

    // Close game
    games[_gameNumber].status = false;

    // Pick winner
    // @todo Track the total pot per game - if multiple games of for the same
    // token are running, calling `endGame` will divi up the entire contract
    // token balance, rather than what was played in specific game
    uint _rand = _randModulus(100);
    uint _total = game.tickets.length - 1;
    uint _index = _rand % _total;
    address _winnerAddress = game.tickets[_index];

    // Game pot
    uint _pot = game.token.balanceOf(address(this));

    // Send fees (if applicable)
    if (game.feePercent > 0) {
      // uint _gameFeePercent = (gameFeePercent / 100);
      // uint _feeTotal = (_gameFeePercent * _pot);
      uint _feeTotal = ABDKMathQuad.toUInt(
        ABDKMathQuad.mul(
          ABDKMathQuad.div(
            ABDKMathQuad.fromUInt(game.feePercent),
            ABDKMathQuad.fromUInt(100)
          ),
          ABDKMathQuad.fromUInt(_pot)
        )
      );

      // Transfer game fee
      game.token.transfer(game.feeAddress, _feeTotal);
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
    game.token.transfer(_winnerAddress, _pot);

    // Fire `GameEnd` event
    emit GameEnd(
      game.number,
      game.tokenAddress,
      _winnerAddress,
      _pot
    );

    // @todo Trim superfluous game data for gas saving
    // _resetGame();
    games[_gameNumber].winnerAddress = _winnerAddress;
    totalGamesEnded++;
  }

  /**
   * @dev Return an array of useful game states
   */
  function getGameState(
    uint _gameNumber
  ) external view
  returns (
    bool status,
    uint number,
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
    Game storage game = games[_gameNumber];

    require(
      game.playerCount >= 0,
      "Invalid game"
    );
    return (
      game.status,
      game.number,
      game.playerCount,
      game.ticketCount,
      game.maxPlayers,
      game.maxTicketsPlayer,
      game.ticketPrice,
      game.feePercent,
      game.feeAddress,
      game.tokenAddress,
      game.winnerAddress
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
    require(
      games[_gameNumber].playerCount >= 0,
      "Invalid game"
    );

    games[_gameNumber].tokenAddress = _token;
    games[_gameNumber].token = ERC20(_token);
    return true;
  }

  /**
   * @dev Define new game ticket price
   */
  function setTicketPrice(
    uint _gameNumber,
    uint _price
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      games[_gameNumber].playerCount >= 0,
      "Invalid game"
    );
    require(
      _price > 0,
      "Price greater than 0"
    );
    games[_gameNumber].ticketPrice = _price;
    return true;
  }

  /**
   * @dev Defines maximum number of unique game players
   */
  function setMaxPlayers(
    uint _gameNumber,
    uint _max
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      games[_gameNumber].playerCount >= 0,
      "Invalid game"
    );
    require(
      _max > 1,
      "Max players greater than 1"
    );
    games[_gameNumber].maxPlayers = _max;
    return true;
  }

  /**
   * @dev Defines maximum number of tickets, per unique game player
   */
  function setMaxTicketsPerPlayer(
    uint _gameNumber,
    uint _max
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      games[_gameNumber].playerCount >= 0,
      "Invalid game"
    );
    require(
      _max > 0,
      "Max tickets greater than 0"
    );
    games[_gameNumber].maxTicketsPlayer = _max;
    return true;
  }

  /**
   * @dev Defines the game fee percentage (can only be lower than original value)
   */
  function setGameFeePercent(
    uint _gameNumber,
    uint _percent
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    Game storage game = games[_gameNumber];

    require(
      game.playerCount >= 0,
      "Invalid game"
    );
    require(
      _percent >= 0,
      "Zero or higher"
    );
    if (game.status == true) {
      require(
        _percent <= game.feePercent,
        "Can only be decreased after game start"
      );
    }
    games[_gameNumber].feePercent = _percent;
    return true;
  }

  /**
   * @dev Defines an address for the game fee
   */
  function setGameFeeAddress(
    uint _gameNumber,
    address _address
  ) external onlyRole(MANAGER_ROLE) returns(bool sufficient) {
    require(
      games[_gameNumber].playerCount >= 0,
      "Invalid game"
    );
    games[_gameNumber].feeAddress = _address;
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