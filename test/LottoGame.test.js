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

    // Start game for LottoToken, exactly one token per entry,
    // max three players, max one ticket per player.
    await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      accounts[8],

      // Game fee percent
      1,

      // Ticket price
      1000,

      // Max players
      3,

      // Max player tickets
      1,

      {from: accounts[0]}
    )

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
    let count = await contract.getGamePlayerCount({from: accounts[1]});
    // console.log(count);
    // expect(count).to.be.bignumber;
    // assert(count === 1, 'Number of players 1');

    // Approve and buy 1 ticket for A2
    await token.approve(contract.address, 5000, {from: accounts[2]});
    await contract.buyTicket(1, {from: accounts[2]})
    let count2 = await contract.getGamePlayerCount({from: accounts[2]});
    // expect(count2).to.be.bignumber;
    // assert(count2 === 2, 'Number of players 2');

    // Approve and buy 1 ticket for A3
    await token.approve(contract.address, 5000, {from: accounts[3]});
    await contract.buyTicket(1, {from: accounts[3]})
    let count3 = await contract.getGamePlayerCount({from: accounts[3]});
    // expect(count3).to.be.bignumber;
    // assert(count3 === 3, 'Number of players 3');

    // Approve and buy 1 ticket for A4 (should fail)
    // await token.approve(contract.address, 100, {from: accounts[4]});
    // await contract.buyTicket(1, {from: accounts[4]})
    // let count4 = await contract.getGamePlayerCount({from: accounts[4]});

    // Choose a random winner
    // let winner = await contract.pickWinner.call({from: accounts[0]});
    // console.log(winner);
    await contract.endGame({from: accounts[0]});

    let fees = await token.balanceOf.call(accounts[8], {from: accounts[0]});
    // let fees = await token.balanceOf(accounts[8], {from: accounts[0]});
    console.log(fees);

    // Start game for LottoToken, exactly two token per entry,
    // max three players, max two tickets per player.
    await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      accounts[9],

      // Game fee percent
      1,

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
    // winner = await contract.pickWinner.call({from: accounts[0]});
    // console.log(winner);

    // Set destination for the game fee.
    // await contract.setGameFeePercent(1, {from: accounts[0]})
    // await contract.setGameFeeAddress(accounts[9], {from: accounts[0]})

    await contract.endGame({from: accounts[0]});
  
  });
});