const { expect, assert } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers');

// Load compiled artifacts
const Oracle = artifacts.require('Oracle');
const LottoGame = artifacts.require('LottoGame');
const LottoToken = artifacts.require('LottoToken');

// Start test block
contract('LottoGame', function ([ creator, other ]) {
  let accounts;
  let oracle;
  let token;
  let contract;

  before(async function () {
    accounts = await web3.eth.getAccounts();
    oracle = await Oracle.new({ from: creator });
    contract = await LottoGame.new(oracle.address, { from: creator });
    token = await LottoToken.new(creator, { from: creator });
  });

  it('should allow accounts to buy tickets', async function () {
    let expected, actual;

    let maxPlayers = 3;
    let maxTicketsPlayer = 1;
    let ticketPrice = 1000;
    let gameFeeAddress = accounts[8];

    // Start game for LottoToken, exactly one token per entry,
    // max three players, max one ticket per player.
    let game0 = await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      gameFeeAddress,

      // Game fee percent
      2,

      // Ticket price
      ticketPrice,

      // Max players
      maxPlayers,

      // Max player tickets
      maxTicketsPlayer,

      {from: accounts[0]}
    )

    // console.log(game0.logs[0].args.gameNumber.toNumber());
    let game0Log = game0.logs[0].args;
    
    expect(game0Log.tokenAddress).to.eql(token.address);
    
    expect(game0Log.feeAddress).to.eql(gameFeeAddress);

    expect(game0Log.gameNumber.toNumber()).to.eql(0);

    expect(game0Log.feePercent.toNumber()).to.eql(2);

    expect(game0Log.ticketPrice.toNumber()).to.eql(ticketPrice);

    expect(game0Log.maxPlayers.toNumber()).to.eql(maxPlayers);

    expect(game0Log.maxTicketsPlayer.toNumber()).to.eql(maxTicketsPlayer);

// return;
    
    // expect(game0State.status).to.eql(true);

    // console.log(actual['feePercent'].toNumber());
    // console.log(actual['feeAddress']);
    // console.log(actual['tokenAddress']);
    // expect(actual['ticketPrice']).to.eql(expected);

    // expected = web3.utils.toBN('1000');
    // return;
    // expect(actual['ticketPrice']).to.eql(expected);
    // return;
    // console.log(expected);
    // expect(actual).to.eql(expected);

    // Number of games is still zero
    // expected = web3.utils.toBN('0');
    // actual = await contract.getGameCount.call({from: accounts[0]});
    // // console.log(actual);
    // // console.log(expected);
    // expect(actual).to.eql(expected);

    // Seed accounts for testing
    // let totalSupply = await token.totalSupply({ from: accounts[0] })
    let approveAmount = ticketPrice * 10;
    await token.approve(accounts[0], (approveAmount * 100), {from: accounts[0]})
    await token.transferFrom(accounts[0], accounts[1], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[2], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[3], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[4], approveAmount, { from: accounts[0] })

    // Approve and buy 1 ticket for A1
    await token.approve(contract.address, 5000, {from: accounts[1]});
    let game0A1Ticket = await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber.toNumber(),
      
      // Number of tickets
      1,
      
      {from: accounts[1]}
    )
    let game0A1TicketLog = game0A1Ticket.logs[0].args;
    
    expect(game0A1TicketLog.playerAddress).to.eql(accounts[1]);

    expect(game0A1TicketLog.gameNumber.toNumber()).to.eql(0);

    expect(game0A1TicketLog.numberOfTickets.toNumber()).to.eql(1);

    // Number of game players increases by one
    expected = web3.utils.toBN('1');
    actual = await contract.totalGames({from: accounts[1]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Buy second ticket for A1 (should fail)
    try {
      await contract.buyTicket(
      
        // Game number
        game0Log.gameNumber.toNumber(),
        
        // Number of tickets
        1,
        
        {from: accounts[1]}
      );
      assert.fail('The transaction should have thrown an error');
    } catch (err) {
      assert.include(
        err.message,
        "Exceeds max player tickets, try lower value",
        "The error message should contain 'Exceeds max player tickets, try lower value'"
      );
    }

    // Approve and buy 1 ticket for A2
    await token.approve(contract.address, 5000, {from: accounts[2]});
    await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber.toNumber(),
      
      // Number of tickets
      1,
      
      {from: accounts[2]}
    )
    
    // Number of game players increases by one, to two
    // expected = web3.utils.toBN('2');
    // actual = await contract.getGamePlayerCount.call({from: accounts[2]});
    // // console.log(actual);
    // // console.log(expected);
    // expect(actual).to.eql(expected);

    // Approve and buy 1 ticket for A3
    await token.approve(contract.address, 5000, {from: accounts[3]});
    await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber.toNumber(),
      
      // Number of tickets
      1,
      
      {from: accounts[3]}
    )
    
    // Number of game players increases by one, to three
    // expected = web3.utils.toBN('3');
    // actual = await contract.getGamePlayerCount.call({from: accounts[3]});
    // // console.log(actual);
    // // console.log(expected);
    // expect(actual).to.eql(expected);

    // Approve for A4
    await token.approve(contract.address, 5000, {from: accounts[4]});
    
    // Buy 1 ticket for A4 (should fail)
    try {
      await contract.buyTicket(
      
        // Game number
        game0Log.gameNumber.toNumber(),
        
        // Number of tickets
        1,
        
        {from: accounts[4]}
      );
      assert.fail('The transaction should have thrown an error');
    } catch (err) {
      assert.include(
        err.message,
        "Too many players in game",
        "The error message should contain 'Too many players in game'"
      );
    }

    // Game fee is 2%
    // expected = web3.utils.toBN('2');
    // actual = await contract.getGameFeePercent.call({from: accounts[1]});
    // // console.log(actual);
    // // console.log(expected);
    // expect(actual).to.eql(expected);

    // Set game fee to 3% (should fail)
    try {
      await contract.setGameFeePercent(
      
        // Game number
        game0Log.gameNumber.toNumber(),
        
        // Game fee percent
        3,
        
        {from: accounts[0]}
      );
      assert.fail('The transaction should have thrown an error');
    } catch (err) {
      assert.include(
        err.message,
        "Can only be decreased after game start",
        "The error message should contain 'Can only be decreased after game start'"
      );
    }

    // Choose a random winner
    let game0EndGame = await contract.endGame(
      
      game0Log.gameNumber.toNumber(),
      
      {from: accounts[0]}
    );
    let game0EndGameLog = game0EndGame.logs[0].args;
    
    expect(game0EndGameLog.tokenAddress).to.eql(token.address);

    // expect(game0EndGameLog.winnerAddress).to.eql(accounts[1]);

    expect(game0EndGameLog.gameNumber.toNumber()).to.eql(0);

    


    // Check game zero states
    game0State = await contract.getGameState.call(
      game0EndGameLog.gameNumber.toNumber(),
      {from: accounts[1]}
    );

    expect(game0State.status).to.eql(false);

    // Needs fee offset calc
    // expect(game0State.pot.toNumber()).to.eql(game0EndGameLog.pot.toNumber());
  
    expect(game0State.playerCount.toNumber()).to.eql(maxPlayers);

    // Each player bought one ticket each
    expect(game0State.ticketCount.toNumber()).to.eql(maxPlayers);

    expect(game0State.maxPlayers.toNumber()).to.eql(maxPlayers);

    expect(game0State.maxTicketsPlayer.toNumber()).to.eql(maxTicketsPlayer);

    expect(game0State.ticketPrice.toNumber()).to.eql(ticketPrice);

    expect(game0State.feeAddress).to.eql(gameFeeAddress);

    expect(game0State.tokenAddress).to.eql(token.address);

    // expect(game0State.winnerAddress).to.eql(token.address);



    // Get last game winner
    // actual = await contract.getGameLastWinner.call({from: accounts[1]});
    // expect(actual).to.be.properAddress;

    // Game count is one





    // Start game for LottoToken, exactly two token per entry,
    // max three players, max two tickets per player.
    let game1StartGame = await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      accounts[9],

      // Game fee percent
      5,

      // Ticket price
      500,
      
      // Max players
      3,

      // Max player tickets
      2,

      {from: accounts[0]}
    );
    let game1StartGameLog = game1StartGame.logs[0].args;
    // console.log(game1StartGameLog);

    // Another game test run, buying two tickets each
    count = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber.toNumber(),
      
      // Number of tickets
      2,
      
      {from: accounts[1]}
    );
    count2 = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber.toNumber(),
      
      // Number of tickets
      2,
      
      {from: accounts[2]}
    );
    count3 = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber.toNumber(),
      
      // Number of tickets
      2,
      
      {from: accounts[3]}
    );

    await contract.endGame(
      game1StartGameLog.gameNumber.toNumber(),
      {from: accounts[0]}
    );
  
  });
});