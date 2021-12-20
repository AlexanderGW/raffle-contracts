pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './LottoToken.sol';
import './Oracle.sol';

contract LottoGame is AccessControl {

	// Game states
	bool public gameState;
	uint public gameComplete;
	uint public gameMaxPlayers;
	uint public gameMaxTicketsPlayer;
	uint public gameTicketPrice;
	// uint[] public gameTickets;

	address public gameLastWinner;

	address public gameTokenAddress;
	// address[] public gamePlayers;


	uint[] public gamePlayers;
	address[] public gameTickets;
	// mapping(uint => address) public gameTickets;
	// mapping(address => uint) public gamePlayers;

	ERC20 gameToken;
    
    // Roles
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

	Oracle oracle;
	
	uint nonce;

	constructor(address _oracleAddress) public {
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

	function resetGame() public onlyRole(CALLER_ROLE) returns(bool sufficient) {
		gameTickets = new address[](0);
		gamePlayers = new uint[](0);
		return true;
	}

	function startGame(
		address _token,
		uint _ticketPrice,
		uint _maxPlayers,
		uint _maxTicketsPlayer
	) public onlyRole(CALLER_ROLE) returns (bool) {
		require(
            gameState == false,
            "Game already started"
        );
		
		gameState = true;

		gameTokenAddress = _token;
		gameToken = ERC20(gameTokenAddress);

        gameMaxPlayers = _maxPlayers;
		gameTicketPrice = _ticketPrice;
		gameMaxTicketsPlayer = _maxTicketsPlayer;

		return true;
	}

	function buyTicket(uint _numberOfTickets) public returns (bool) {
		require(
            gameState == true,
            "Game has not started"
        );
        require(
            gameToken.allowance(msg.sender, address(this)) >= (gameTicketPrice * _numberOfTickets),
            "Insufficent game token allowance"
        );
        require(
            gameTickets.length <= gameMaxPlayers,
            "Too many players in this game"
        );
        require(
            _numberOfTickets > 0,
            "Number of tickets must be at least 1"
        );
		// uint256 gamePlayersIndex = uint256(uint160(address(msg.sender)));
		// uint playerTicketCount = uint(gamePlayers[gamePlayersIndex] + _numberOfTickets);
        // require(
        //     playerTicketCount <= gameMaxTicketsPlayer,
        //     "You have already bought the maximum number of tickets"
        // );

		_safeTransferFrom(gameToken, msg.sender, address(this), (gameTicketPrice * _numberOfTickets));

		// gamePlayers[gamePlayersIndex] = playerTicketCount;
		uint i;
		while (i != _numberOfTickets) {
			gameTickets.push(msg.sender);
			i++;
		}

		return true;
		// return gamePlayers[gamePlayersIndex];
		// return ++gamePlayers[msg.sender];
	}

	function endGame() public onlyRole(CALLER_ROLE) returns (address) {
		require(
            gameState == true,
            "Game already ended"
        );
        require(
            gameTickets.length > 2,
            "Need at least two players in game"
        );

		gameState = false;

		uint rand = _randModulus(100);
		uint index = rand % gameTickets.length;
		gameLastWinner = gameTickets[index];

		gameToken.transfer(gameLastWinner, gameToken.balanceOf(address(this)));

		resetGame();
		gameComplete++;

		return gameLastWinner;
	}

	// function getPlayers() public view returns (address[]) {
	// 	return gameTickets;
	// }

	// function getGameCompleteCount() public returns(uint) {
	// 	return uint(gameComplete);
	// }

	function getGamePlayerCount() public returns(uint) {
		return uint(gamePlayers.length);
	}

	function getGameToken() public returns(address) {
		return gameTokenAddress;
	}

	function setGameToken(address _token) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
		gameTokenAddress = _token;
		gameToken = ERC20(gameTokenAddress);
		return true;
	}

	// function getTicketPrice() public returns(uint) {
	// 	return gameTicketPrice;
	// }

	function setTicketPrice(uint _price) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
		gameTicketPrice = _price;
		return true;
	}

	// function getMaxPlayers() public returns(uint) {
	// 	return gameMaxPlayers;
	// }

	function setMaxPlayers(uint _max) public onlyRole(MANAGER_ROLE) returns(bool sufficient) {
		gameMaxPlayers = _max;
		return true;
	}

	// function getMaxTickets() public returns(uint) {
	// 	return gameMaxTicketsPlayer;
	// }

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