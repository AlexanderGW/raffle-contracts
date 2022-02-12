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

    // Start game for LottoToken, exactly one token per entry,
    // max three players, max one ticket per player.
    await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      accounts[8],

      // Game fee percent
      2,

      // Ticket price
      1000,

      // Max players
      3,

      // Max player tickets
      1,

      {from: accounts[0]}
    )

    // Number of games is still zero
    expected = web3.utils.toBN('0');
    actual = await contract.getGameCount.call({from: accounts[0]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Seed accounts for testing
    // let totalSupply = await token.totalSupply({ from: accounts[0] })
    await token.approve(accounts[0], 100000, {from: accounts[0]})
    await token.transferFrom(accounts[0], accounts[1], 10000, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[2], 10000, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[3], 10000, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[4], 10000, { from: accounts[0] })

    // Approve and buy 1 ticket for A1
    await token.approve(contract.address, 5000, {from: accounts[1]});
    await contract.buyTicket(1, {from: accounts[1]})
    
    // Number of game players increases by one
    expected = web3.utils.toBN('1');
    actual = await contract.getGamePlayerCount.call({from: accounts[1]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Buy second ticket for A1 (should fail)
    try {
      await contract.buyTicket(1, {from: accounts[1]});
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
    await contract.buyTicket(1, {from: accounts[2]})
    
    // Number of game players increases by one, to two
    expected = web3.utils.toBN('2');
    actual = await contract.getGamePlayerCount.call({from: accounts[2]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Approve and buy 1 ticket for A3
    await token.approve(contract.address, 5000, {from: accounts[3]});
    await contract.buyTicket(1, {from: accounts[3]})
    
    // Number of game players increases by one, to three
    expected = web3.utils.toBN('3');
    actual = await contract.getGamePlayerCount.call({from: accounts[3]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Approve for A4
    await token.approve(contract.address, 5000, {from: accounts[4]});
    
    // Buy 1 ticket for A4 (should fail)
    try {
      await contract.buyTicket(1, {from: accounts[4]});
      assert.fail('The transaction should have thrown an error');
    } catch (err) {
      assert.include(
        err.message,
        "Too many players in game",
        "The error message should contain 'Too many players in game'"
      );
    }

    // Game fee is 2%
    expected = web3.utils.toBN('2');
    actual = await contract.getGameFeePercent.call({from: accounts[1]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);

    // Set game fee to 3% (should fail)
    try {
      await contract.setGameFeePercent(3, {from: accounts[0]});
      assert.fail('The transaction should have thrown an error');
    } catch (err) {
      assert.include(
        err.message,
        "Can only be decreased after game start",
        "The error message should contain 'Can only be decreased after game start'"
      );
    }

    // Choose a random winner
    await contract.endGame({from: accounts[0]});

    // Get last game winner
    // actual = await contract.getGameLastWinner.call({from: accounts[1]});
    // expect(actual).to.be.properAddress;

    // Game count is one
    expected = web3.utils.toBN('1');
    actual = await contract.getGameCount.call({from: accounts[1]});
    // console.log(actual);
    // console.log(expected);
    expect(actual).to.eql(expected);





    // Start game for LottoToken, exactly two token per entry,
    // max three players, max two tickets per player.
    await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      accounts[9],

      // Game fee percent
      5,

      // Ticket price
      2000,
      
      // Max players
      3,

      // Max player tickets
      2,

      {from: accounts[0]}
    )

    // Another game test run, buying two tickets each
    count = await contract.buyTicket(2, {from: accounts[1]});
    count2 = await contract.buyTicket(2, {from: accounts[2]});
    count3 = await contract.buyTicket(2, {from: accounts[3]});

    await contract.endGame({from: accounts[0]});
  
  });
});