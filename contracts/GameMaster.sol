// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import './Oracle.sol';

contract GameMaster is AccessControl, ERC721Holder {
  using SafeMath for uint128;
  using SafeMath for uint256;

  /**
   * @dev Game pot record struct
   */
  struct GamePot {

    /**
     * @dev Value of the asset (token amount, ERC721 collection index)
     */
    uint248 value;

    /**
     * @dev Type of asset
     * 0 = ERC20
     * 1 = ERC721
     */
    uint8 assetType;

    /**
     * @dev Address of the asset
     */
    address assetAddress;
  }

  /**
   * @dev Game record struct
   */
  struct Game {

    /**
     * @dev Current state of the game
     * 0 = Game has ended
     * 1 = House game is active
     * 2 = Community game is active
     */
    uint8 status;

    /**
     * @dev Number assigned to the game (sequental, based on total games)
     */
    uint32 number;

    /**
     * @dev Total value of token pot
     */
    // uint256 pot;

    /**
     * @dev Number of game pots
     */
    uint8 potCount;

    /**
     * @dev Number of players in the current game
     */
    uint16 playerCount;

    /**
     * @dev Number of all player tickets in the current game
     */
    uint24 ticketCount;

    /**
     * @dev Maximum number of players allowed in the game
     */
    uint16 maxPlayers;

    /**
     * @dev Maximum number of tickets per player
     */
    uint16 maxTicketsPlayer;

    /**
     * @dev Single ticket price
     */
    uint128 ticketPrice;

    /**
     * @dev Percentage (hundredth) of the pot zero will go to `gameFeeAddress`.
     * Zero value disables feature
     */
    uint8 feePercent;

    /**
     * @dev Address of user that actioned this `startGame()`
     */
    address ownerAddress;

    /**
     * @dev Winner result (i.e. single ticket index for raffle, or multiple numbers for lotto)
     */
    uint32[] winnerResult;

    /**
     * @dev Destination for the game fee tokens
     */
    address feeAddress;

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
     * @dev List of unique game players, and total number of tickets
     */
    mapping (address => uint32) playerTicketCount;

    /**
     * @dev List of unique game players
     */
    mapping (uint8 => GamePot) pot;
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
   * @dev All community game fees are sent to this address
   */
  address public treasuryAddress;

  /**
   * @dev Percentage (hundredth) of the game pot zero will go to `treasuryAddress`.
   * This is deducted before the game defined `feeAddress`, in `endGame()`. Zero value disables feature
   */
  uint256 public treasuryFeePercent;

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
    address indexed ticketTokenAddress,
    address indexed feeAddress,
    uint32 indexed gameNumber,
    uint8 feePercent,
    uint128 ticketPrice,
    uint16 maxPlayers,
    uint16 maxTicketsPlayer
  );

  /**
   * @dev Emitted when a game's parameters are changed
   */
  event GameChanged(
    uint32 indexed gameNumber
  );

  /**
   * @dev Emitted when a player buys ticket(s)
   */
  event TicketBought(
    address indexed playerAddress,
    uint32 indexed gameNumber,
    uint16 playerCount,
    uint24 ticketCount
  );

  /**
   * @dev Emitted when a game ends, and a player has won
   */
  event GameEnded(
    address indexed ticketTokenAddress,
    address indexed winnerAddress,
    uint32 indexed gameNumber,
    uint32[] winnerResult,
    GamePot[] pot
  );

  /**
   * @dev Setup contract
   */
  constructor(
    address _oracleAddress
  ) {

    // Oracle of randomness - This oracle needs to be fed regularly
    oracle = Oracle(_oracleAddress);

    // Address where community game fees are sent
    treasuryAddress = msg.sender;

    // Set a default treasure fee of 5%, for community games
    treasuryFeePercent = 5;

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
  // function _resetGame(
  //   uint32 _gameNumber
  // ) private {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );

  //   g.tickets = new address[](0);
  //   address j;
  //   for (uint256 i = 0; i < g.playerCount; i++) {
  //     j = g.playersIndex[i];
  //     delete g.playerTicketCount[j];
  //   }
  //   g.playersIndex = new address[](0);
  //   g.playerCount = 0;
  //   g.ticketCount = 0;
  // }

  /**
   * @dev Game reset call for managers
   */
  // function resetGame(
  //   uint32 _gameNumber
  // ) external onlyRole(MANAGER_ROLE) {
  //   _resetGame(_gameNumber);
  // }

  /**
   * @dev Start a new game (if none running) with given parameters
   */
  function _startGame(
    address _gameTokenAddress,
    address _gameFeeAddress,
    uint8 _gameFeePercent,
    uint128 _ticketPrice,
    uint16 _maxPlayers,
    uint16 _maxTicketsPlayer,
    uint8 _gameStatus
  ) private {
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
    require(
      _gameFeePercent >= 0 && _gameFeePercent <= 100,
      "Fee range 0-100"
    );

    // Get game number
    uint32 _gameNumber = uint32(totalGames);

    totalGames++;

    // Create new game record
    Game storage g = games[_gameNumber];
    g.status = _gameStatus;
    g.number = _gameNumber;
    g.playerCount = 0;
    g.ticketCount = 0;
    g.maxPlayers = _maxPlayers;
    g.maxTicketsPlayer = _maxTicketsPlayer;
    g.ticketPrice = _ticketPrice;
    g.feePercent = _gameFeePercent;
    g.feeAddress = _gameFeeAddress;

    // Used to identify the owner of a community game
    if (_gameStatus == 2)
      g.ownerAddress = msg.sender;

    g.potCount = 1;

    // Create initial game token pot, as index zero
    g.pot[0] = GamePot(

      // value
      0,

      // assetType
      0,

      // assetAddress
      _gameTokenAddress
    );

    // Fire `GameStarted` event
    emit GameStarted(
      _gameTokenAddress,
      g.feeAddress,
      g.number,
      g.feePercent,
      g.ticketPrice,
      g.maxPlayers,
      g.maxTicketsPlayer
    );
  }

  /**
   * @dev Start a new game (if none running) with given parameters
   */
  function startGame(
    address _gameTokenAddress,
    address _gameFeeAddress,
    uint8 _gameFeePercent,
    uint128 _ticketPrice,
    uint16 _maxPlayers,
    uint16 _maxTicketsPlayer
  ) external {

    // Default to community game
    uint8 _gameStatus = 2;
    
    // User has CALLER_ROLE, switch to house game
    if (hasRole(CALLER_ROLE, msg.sender)) {
      _gameStatus = 1;
    }

    _startGame(
      _gameTokenAddress,
      _gameFeeAddress,
      _gameFeePercent,
      _ticketPrice,
      _maxPlayers,
      _maxTicketsPlayer,
      _gameStatus
    );
  }

  // function startCommunityGame(
  //   address _gameTokenAddress,
  //   address _gameFeeAddress,
  //   uint8 _gameFeePercent,
  //   uint128 _ticketPrice,
  //   uint16 _maxPlayers,
  //   uint16 _maxTicketsPlayer
  // ) external {

  //   // All community games are status `2`
  //   uint8 _gameStatus = 2;

  //   _startGame(
  //     _gameTokenAddress,
  //     _gameFeeAddress,
  //     _gameFeePercent,
  //     _ticketPrice,
  //     _maxPlayers,
  //     _maxTicketsPlayer,
  //     _gameStatus
  //   );
  // }

// TODO: Free ticket support

  /**
   * @dev Allow a player to buy Nth tickets in `_gameNumber`, at predefined `g.ticketPrice` of `g.pot[0].assetAddress`
   */
  function buyTicket(
    uint32 _gameNumber,
    uint8 _numberOfTickets
  ) external {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers >= 0,
      "Invalid game"
    );
    require(
      g.status > 0,
      "Game already ended"
    );
    require(
      _numberOfTickets > 0,
      "Buy at least 1 ticket"
    );
    
    IERC20Metadata _token = IERC20Metadata(g.pot[0].assetAddress);

    // Ensure player has enough tokens to play
    uint256 _totalCost = g.ticketPrice.mul(_numberOfTickets);
    require(
      _token.allowance(msg.sender, address(this)) >= _totalCost,
      "Insufficent game token allowance"
    );

    // Marker for new player logic
    bool _isNewPlayer = false;

    // Current number of tickets that this player has
    uint32 _playerTicketCount = g.playerTicketCount[msg.sender];

    // First time player has entered the game
    if (_playerTicketCount == 0) {
      if (g.playerCount == g.maxPlayers) {
        revert("Too many players in game");
      }
      _isNewPlayer = true;
    }
    
    // Check the new player ticket count
    uint32 _playerTicketNextCount = _playerTicketCount + _numberOfTickets;
    require(
      _playerTicketNextCount <= g.maxTicketsPlayer,
      "Exceeds max player tickets, try lower value"
    );

    // Transfer `_totalCost` of `gameToken` from player, this this contract
    _safeTransferFrom(
      _token,
      msg.sender,
      address(this),
      _totalCost
    );

    // Add total ticket cost to game ticket pot (always index zero)
    g.pot[0].value += uint128(_totalCost);

    // If a new player (currently has no tickets)
    if (_isNewPlayer) {

      // Increase game total player count
      g.playerCount++;

      // Used for iteration on game player mapping, when resetting game
      g.playersIndex.push(msg.sender);
    }

    // Update number of tickets purchased by player
    g.playerTicketCount[msg.sender] = _playerTicketNextCount;

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
   * @dev Is `msg.sender` authorised to modify game `_gameNumber`
   */
  function isAuthorised(
    uint32 _gameNumber
  ) public view returns(
    bool 
  ) {
    Game storage g = games[_gameNumber];

    if (

      // Only owner of community game
      (g.status == 2 && g.ownerAddress == msg.sender)

      // If user has CALLER_ROLE, for house games
      || (g.status == 1 && hasRole(CALLER_ROLE, msg.sender))
    ) {
      return true;
    }

    return false;
  }

  /**
   * @dev Ends the current game, and picks a winner (requires `MANAGER_ROLE` or owner, if community game)
   */
  function endGame(
    uint32 _gameNumber
  ) external returns(
    bool
  ) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers >= 0,
      "Invalid game"
    );
    require(
      g.status > 0,
      "Game already ended"
    );

    if (
      g.status == 2
      && g.ownerAddress != msg.sender
      && !hasRole(MANAGER_ROLE, msg.sender)
    ) {
      revert("Only manager role, or owner of game");
    }

    if (
      g.status == 1
      && !hasRole(CALLER_ROLE, msg.sender)
    ) {
      revert("Only caller role");
    }
    
    IERC20Metadata _token = IERC20Metadata(g.pot[0].assetAddress);

    // Check contract holds enough balance in game token (pot zero), to send to winner
    uint256 _ticketPot = g.pot[0].value;
    uint256 _balance = _token.balanceOf(address(this));
    require(
      _ticketPot <= _balance,
      "Not enough of game token in reserve"
    );

    // Close game
    uint8 _gameStatus = g.status;
    g.status = 0;

    // Pick winner
    uint256 _rand = _randModulus(100);
    uint24 _total = g.ticketCount - 1;
    uint24 _index = (_total == 0) ? 0 : uint24(_rand % _total);

    // Store winner result index
    g.winnerResult.push(_index);

    // Store winner address index
    g.winnerAddress = g.tickets[_index];

    // Send treasury fee (if applicable, only for community games)
    if (_gameStatus == 2 && treasuryFeePercent > 0) {
      uint256 _treasuryFeeTotal = _ticketPot.div(100).mul(treasuryFeePercent);

      // Transfer treasury fee from pot
      if (_treasuryFeeTotal > 0) {
        _token.transfer(treasuryAddress, _treasuryFeeTotal);

        // Deduct fee from pot value
        _ticketPot -= _treasuryFeeTotal;
      }
    }

    // Send game fee (if applicable)
    if (g.feePercent > 0) {
      uint256 _gameFeeTotal = _ticketPot.div(100).mul(g.feePercent);

      // Transfer game fee from pot
      if (_gameFeeTotal > 0) {
        _token.transfer(g.feeAddress, _gameFeeTotal);

        // Deduct fee from pot value
        _ticketPot -= _gameFeeTotal;
      }
    }

    // Transfer any other `GamePot` assets
    GamePot[] memory _pots = new GamePot[](g.potCount);
    for (uint8 _i = 0; _i < g.potCount; _i++) {

      // Skip null (removed) asset records
      if (g.pot[_i].assetAddress == address(0)) continue;

      // Add pot record, for event record
      _pots[_i] = g.pot[_i];

      // Handled outside of this for loop
      if (_i == 0) continue;

      // ERC20
      if (g.pot[_i].assetType == 0) {
        IERC20Metadata(
          g.pot[_i].assetAddress
        )
        .transfer(
          g.winnerAddress,
          uint256(_pots[_i].value)
        );
      }

      // ERC721
      else if (g.pot[_i].assetType == 1) {
        IERC721Metadata(
          g.pot[_i].assetAddress
        )
        .safeTransferFrom(
          address(this),
          g.winnerAddress,
          uint256(_pots[_i].value)
        );
      }

      // Unsupported asset type
      else revert("Unknown asset type");
    }

    // Send game token pot to winner
    _token.transfer(g.winnerAddress, _ticketPot);

    // @todo Trim superfluous game data for gas saving
    totalGamesEnded++;

    // Fire `GameEnded` event
    emit GameEnded(
      g.pot[0].assetAddress,
      g.winnerAddress,
      g.number,
      g.winnerResult,
      _pots
    );

    return true;
  }

  /**
   * @dev Add an additional pot asset to a game
   */
  function _addGamePotAsset(
    uint32 _gameNumber,
    uint8 _assetType,
    uint248 _assetValue,
    address _assetAddress
  ) internal {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status > 0,
      "Game already ended"
    );
    
    // ERC20
    if (_assetType == 0) {
      IERC20Metadata _assetInterface = IERC20Metadata(_assetAddress);

      _safeTransferFrom(
        _assetInterface,
        msg.sender,
        address(this),
        uint256(_assetValue)
      );
    }

    // ERC721
    else if (_assetType == 1) {
      IERC721Metadata _assetInterface = IERC721Metadata(_assetAddress);

      _assetInterface.safeTransferFrom(
        msg.sender,
        address(this),
        uint256(_assetValue)
      );
    }

    // Unsupported asset type
    else revert("Unknown asset type");

    // Create initial game token pot, as index zero
    g.pot[g.potCount] = GamePot(

      // value
      _assetValue,

      // assetType
      _assetType,

      // assetAddress
      _assetAddress
    );

    // Increase total number of pot assets for the game
    g.potCount++;

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Add an additional pot asset to a game
   */
  function addGamePotERC20Asset(
    uint32 _gameNumber,
    uint248 _assetAmount,
    address _assetAddress
  ) external {
    require(
      isAuthorised(_gameNumber),
      "Not authorised"
    );

    _addGamePotAsset(
      _gameNumber,
      0,
      _assetAmount,
      _assetAddress
    );
  }

  /**
   * @dev Add an additional pot asset to a game
   */
  function addGamePotERC721Asset(
    uint32 _gameNumber,
    uint248 _assetIndex,
    address _assetAddress
  ) external {
    require(
      isAuthorised(_gameNumber),
      "Not authorised"
    );

    _addGamePotAsset(
      _gameNumber,
      1,
      _assetIndex,
      _assetAddress
    );
  }

  /**
   * @dev Add an additional pot asset to a game
   */
  function _removeGamePotAsset(
    uint32 _gameNumber,
    uint8 _assetType,
    uint248 _assetValue,
    address _assetAddress
  ) internal {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );
    require(
      g.status > 0,
      "Game already ended"
    );

    // Check asset entry exists - skip pot zero (ticket price pot)
    for (uint8 _i = 1; _i < g.potCount; _i++) {
      GamePot memory pot = g.pot[_i];

      // Look for matching asset, transfer to sender, and delete entry
      if (
        pot.assetType == _assetType
        && pot.value == _assetValue
        && pot.assetAddress == _assetAddress
      ) {

        // ERC20
        if (_assetType == 0) {
          IERC20Metadata _assetInterface = IERC20Metadata(_assetAddress);

          _assetInterface.transfer(
            msg.sender,
            uint256(pot.value)
          );
        }

        // ERC721
        else if (_assetType == 1) {
          IERC721Metadata _assetInterface = IERC721Metadata(_assetAddress);

          _assetInterface.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(_assetValue)
          );
        }

        // Unsupported asset type
        else revert("Unknown asset type");

        // Delete game pot entry
        delete g.pot[_i];
      }
    }

    // Fire `GameChanged` event
    emit GameChanged(
      g.number
    );
  }

  /**
   * @dev Remove an ERC20 pot asset from a game
   */
  function removeGamePotERC20Asset(
    uint32 _gameNumber,
    uint248 _assetAmount,
    address _assetAddress
  ) external {
    require(
      isAuthorised(_gameNumber),
      "Not authorised"
    );

    _removeGamePotAsset(
      _gameNumber,
      0,
      _assetAmount,
      _assetAddress
    );
  }

  /**
   * @dev Remove an ERC721 pot asset from a game
   */
  function removeGamePotERC721Asset(
    uint32 _gameNumber,
    uint248 _assetIndex,
    address _assetAddress
  ) external {
    require(
      isAuthorised(_gameNumber),
      "Not authorised"
    );

    _removeGamePotAsset(
      _gameNumber,
      1,
      _assetIndex,
      _assetAddress
    );
  }

  /**
   * @dev Return `_total` active games (newest first)
   */
  function getActiveGames(
    uint256 _total
  )
  external view
  returns (
    uint256[] memory gameNumbers
  ) {

    uint256 _i;
    uint256 size = totalGames < _total ? totalGames : _total;
    uint256 limit = totalGames < _total ? 0 : totalGames.sub(_total);
    uint256[] memory _gameNumbers = new uint256[](size);
    for (uint256 _j = totalGames; _j > limit; _j--) {
      if (games[_j].status > 0) {
        _gameNumbers[_i] = _j;
        _i++;
      }
    }

    return _gameNumbers;
  }

  /**
   * @dev Return an array of useful game states
   */
  function getGameState(
    uint32 _gameNumber
  ) external view
  returns (
    uint8 status,
    GamePot[] memory pot,
    uint16 playerCount,
    uint24 ticketCount,
    uint16 maxPlayers,
    uint16 maxTicketsPlayer,
    uint128 ticketPrice,
    uint8 feePercent,
    address feeAddress,
    address ownerAddress,
    address winnerAddress,
    uint32[] memory winnerResult
  ) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );

    GamePot[] memory _pots = new GamePot[](g.potCount);
    for (uint8 _i = 0; _i < g.potCount; _i++) {
      _pots[_i] = g.pot[_i];
    }

    return (
      g.status,
      _pots,
      g.playerCount,
      g.ticketCount,
      g.maxPlayers,
      g.maxTicketsPlayer,
      g.ticketPrice,
      g.feePercent,
      g.feeAddress,
      g.ownerAddress,
      g.winnerAddress,
      g.winnerResult
    );
  }
  
  /**
   * @dev Return an array of tickets in game, by player address
   */
  function getGamePlayerState(
    uint32 _gameNumber,
    address _address
  ) external view
  returns (
    uint24[] memory tickets
  ) {
    Game storage g = games[_gameNumber];

    require(
      g.maxPlayers > 0,
      "Invalid game"
    );

    uint24 _i;
    uint24[] memory _tickets = new uint24[](g.playerTicketCount[_address]);
    for (uint24 _j = 0; _j < g.tickets.length; _j++) {
      if (g.tickets[_j] == _address) {
        _tickets[_i] = _j;
        _i++;
      }
    }

    return _tickets;
  }

  /**
   * @dev Define new `treasuryAddress`
   */
  function setTreasuryAddress(
    address _address
  ) external onlyRole(MANAGER_ROLE) {
    treasuryAddress = _address;
  }

  /**
   * @dev Define new `treasuryFeePercent`
   */
  function setTreasuryFeePercent(
    uint8 _feePercent
  ) external onlyRole(MANAGER_ROLE) {
    require(
      _feePercent >= 0 && _feePercent <= 50,
      "Range 0-50"
    );

    treasuryFeePercent = _feePercent;
  }

  /**
   * @dev Define new ERC20 `gameToken` with provided `_token`
   */
  // function setGameToken(
  //   uint32 _gameNumber,
  //   address _token
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );
  //   require(
  //     g.playerCount == 0,
  //     "Can only be changed if 0 players"
  //   );

  //   g.pot[0].assetAddress = _token;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

  /**
   * @dev Define new game ticket price
   */
  // function setTicketPrice(
  //   uint32 _gameNumber,
  //   uint128 _price
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );
  //   require(
  //     g.playerCount == 0,
  //     "Can only be changed if 0 players"
  //   );
  //   require(
  //     _price > 0,
  //     "Price greater than 0"
  //   );

  //   g.ticketPrice = _price;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

  /**
   * @dev Defines maximum number of unique game players
   */
  // function setMaxPlayers(
  //   uint32 _gameNumber,
  //   uint16 _max
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );
  //   require(
  //     _max > 1,
  //     "Max players greater than 1"
  //   );

  //   g.maxPlayers = _max;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

  /**
   * @dev Defines maximum number of tickets, per unique game player
   */
  // function setMaxTicketsPerPlayer(
  //   uint32 _gameNumber,
  //   uint16 _max
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );
  //   require(
  //     _max > 0,
  //     "Max tickets greater than 0"
  //   );

  //   g.maxTicketsPlayer = _max;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

  /**
   * @dev Defines the game fee percentage (can only be lower than original value)
   */
  // function setGameFeePercent(
  //   uint32 _gameNumber,
  //   uint8 _percent
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );
  //   require(
  //     _percent >= 0,
  //     "Zero or higher"
  //   );
  //   require(
  //     _percent < g.feePercent,
  //     "Can only be decreased after game start"
  //   );

  //   g.feePercent = _percent;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

  /**
   * @dev Defines an address for the game fee
   */
  // function setGameFeeAddress(
  //   uint32 _gameNumber,
  //   address _address
  // ) external onlyRole(MANAGER_ROLE) {
  //   Game storage g = games[_gameNumber];

  //   require(
  //     g.maxPlayers > 0,
  //     "Invalid game"
  //   );
  //   require(
  //     g.status > 0,
  //     "Game already ended"
  //   );

  //   g.feeAddress = _address;

  //   // Fire `GameChanged` event
  //   emit GameChanged(
  //     g.number
  //   );
  // }

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