const { expect, assert } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers');

// TODO: Allow public to run games in wrapper function and fixed fee (on top of original fee system that user can control)
// TODO: Community run games, with pausing system
// TODO: Game cancel/reversal?

// Load compiled artifacts
const Oracle = artifacts.require('Oracle');
const GameMaster = artifacts.require('GameMaster');
const GameBobToken = artifacts.require('GameBobToken');
const GameTrophyERC721 = artifacts.require('GameTrophyERC721');

// Start test block
contract('GameMaster', function ([ creator, other ]) {
  let accounts;
  let oracle;
  let contract;
  let token;
  let nft;

  before(async function () {
    accounts = await web3.eth.getAccounts();
    oracle = await Oracle.new({ from: creator });
    contract = await GameMaster.new(oracle.address, { from: creator });
    token = await GameBobToken.new(creator, { from: creator });
    nft = await GameTrophyERC721.new({ from: creator });
    decimals = web3.utils.toBN(18);
  });

  it('should allow un-roled account to run community game', async function () {

    // Seed accounts and set approvals for testing
    await token.approve(
      accounts[0],
      web3.utils.toBN(1000000).mul(web3.utils.toBN(10).pow(decimals)),
      {from: accounts[0]}
    )

    let approveAmount = web3.utils.toBN(10000).mul(web3.utils.toBN(10).pow(decimals));
    await token.transferFrom(accounts[0], accounts[1], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[2], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[3], approveAmount, { from: accounts[0] })
    await token.transferFrom(accounts[0], accounts[4], approveAmount, { from: accounts[0] })

    let approveAmount100K = web3.utils.toBN(100000).mul(web3.utils.toBN(10).pow(decimals));
    await token.approve(contract.address, approveAmount100K, {from: accounts[0]});
    await token.approve(contract.address, approveAmount100K, {from: accounts[1]});
    await token.approve(contract.address, approveAmount100K, {from: accounts[2]});
    await token.approve(contract.address, approveAmount100K, {from: accounts[3]});
    await token.approve(contract.address, approveAmount100K, {from: accounts[4]});

    let maxPlayers = web3.utils.toBN('3');
    let maxTicketsPlayer = web3.utils.toBN('2');
    let gameFeePercent = web3.utils.toBN('50');
    let ticketPrice = web3.utils.toBN('1').mul(web3.utils.toBN(10).pow(decimals));
    let numberOfTickets = web3.utils.toBN('1');
    let gameFeeAddress = accounts[8];

    let treasuryAddress = accounts[9];

    // Defaults to the `msg.sender` (account 0) - change to A9 for easy balance testing
    await contract.setTreasuryAddress(

      // Token address
      treasuryAddress,

      {from: accounts[0]}
    );
    let treasuryAddressState = await contract.treasuryAddress.call({from: accounts[2]});
    // console.log('treasuryAddress: ' + treasuryAddressState);
    
    // Start game for GameBobToken, exactly two token per entry,
    // max three players, max two tickets per player.
    let gameStartCommunityGame = await contract.startGame(

      // Token address
      token.address,

      // Game fee address
      gameFeeAddress,

      // Game fee percent
      gameFeePercent,

      // Ticket price
      ticketPrice,
      
      // Max players
      maxPlayers,

      // Max player tickets
      maxTicketsPlayer,

      {from: accounts[1]}
    );

    let gameStartCommunityGameLog = gameStartCommunityGame.logs[0].args;
    // console.log(gameStartCommunityGameLog);

    // Another game test run, buying two tickets each
    await contract.buyTicket(
      
      // Game number
      gameStartCommunityGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[1]}
    );
    await contract.buyTicket(
      
      // Game number
      gameStartCommunityGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[2]}
    );
    await contract.buyTicket(
      
      // Game number
      gameStartCommunityGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[3]}
    )

    // End community game from an account that didn't create it (should fail)
    // try {
    //   await contract.endGame(
    //     gameStartCommunityGameLog.gameNumber,
    //     {from: accounts[2]}
    //   );
    //   assert.fail('The transaction should have thrown an error');
    // } catch (err) {
    //   assert.include(
    //     err.message,
    //     "Only manager role, or owner of game",
    //     "The error message should contain 'Only manager role, or owner of game'"
    //   );
    
    // }

    // End community game, from a `MANAGER_ROLE` account
    let gameEndCommunityGameAsManagerCall = await contract.endGame.call(
      gameStartCommunityGameLog.gameNumber,
      {from: accounts[0]}
    );
    // console.log(gameEndCommunityGameAsManagerCall);
    expect(gameEndCommunityGameAsManagerCall).to.be.equal(true);

    // End community game, from same account that created it
    let gameEndCommunityGame = await contract.endGame(
      gameStartCommunityGameLog.gameNumber,
      {from: accounts[1]}
    );

    // tickets = 3 * 1 = 3
    // treasuryfee = 5% (default) = 0.15 @ msg.sender (default)
    // game fee =  50% = 1.425 @ A[6]
    // winner = 1.425

    let gameEndCommunityGameLog = gameEndCommunityGame.logs[0].args;
    // console.log(gameEndCommunityGameLog);

    let treasuryAddressBalance = await token.balanceOf.call(treasuryAddress, {from: accounts[2]});
    // console.log('treasuryAddressBalance: ' + treasuryAddressBalance.toString());
    expect(treasuryAddressBalance).to.eql(web3.utils.toBN('150000000000000000'));

    let gameFeeAddressBalance = await token.balanceOf.call(gameFeeAddress, {from: accounts[2]});
    // console.log('gameFeeAddressBalance: ' + gameFeeAddressBalance.toString());
    expect(gameFeeAddressBalance).to.eql(web3.utils.toBN('1425000000000000000'));

    let winnerBalance = await token.balanceOf.call(gameEndCommunityGameLog.winnerAddress, {from: accounts[2]});
    // console.log('winnerBalance: ' + winnerBalance.toString());
    
    // Initial seed amount of 10k, plus original ticket cost of 1, plus the 0.35 offset
    expect(winnerBalance).to.eql(web3.utils.toBN('10000425000000000000000'));
  });
});