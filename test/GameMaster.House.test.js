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
const GameTrophyERC1155 = artifacts.require('GameTrophyERC1155');

// Start test block
contract('GameMaster', function ([ creator, other ]) {
  let accounts;
  let oracle;
  let contract;
  let token;
  let nftERC721;
  let nftERC1155;

  before(async function () {
    accounts = await web3.eth.getAccounts();
    oracle = await Oracle.new({ from: creator });
    contract = await GameMaster.new(oracle.address, { from: creator });
    token = await GameBobToken.new(creator, { from: creator });
    nftERC721 = await GameTrophyERC721.new({ from: creator });
    nftERC1155 = await GameTrophyERC1155.new({ from: creator });
    decimals = web3.utils.toBN(18);
  });

  it('should allow roled account to run house game', async function () {
    let expected, actual;

    let nftERC721Asset0 = await nftERC721.awardItem(
      accounts[0],
      'http://localhost:3200/nftERC721Asset0.jpg',
      {from: accounts[0]}
    );
    // console.log(nftERC721Asset0.logs[0].args.tokenId);
    // return;

    let nftERC721Asset1 = await nftERC721.awardItem(
      accounts[0],
      'http://localhost:3200/nftERC721Asset1.jpg',
      {from: accounts[0]}
    );
    // console.log(nftERC721Asset1.logs[0].args.tokenId);
    // return;

    let nftERC1155Asset0 = await nftERC1155.awardItem(
      accounts[0],
      {from: accounts[0]}
    );
    // console.log(nftERC1155Asset0.logs[0].args.id.toNumber());
    // return;

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

    await nftERC721.approve(
      contract.address,
      nftERC721Asset0.logs[0].args.tokenId,
      {from: accounts[0]}
    );

    await nftERC721.approve(
      contract.address,
      nftERC721Asset1.logs[0].args.tokenId,
      {from: accounts[0]}
    );

    await nftERC1155.setApprovalForAll(
      contract.address,
      {from: accounts[0]}
    );


    let maxPlayers = web3.utils.toBN('3');
    let maxTicketsPlayer = web3.utils.toBN('10');
    let gameFeePercent = web3.utils.toBN('0');//web3.utils.toBN('1').mul(web3.utils.toBN(10).pow(decimals));
    let ticketPrice = web3.utils.toBN('1').mul(web3.utils.toBN(10).pow(decimals));
    let numberOfTickets = web3.utils.toBN('10');
    let gameFeeAddress = accounts[9];

    // Start game for GameBobToken, exactly one token per entry,
    // max three players, max one ticket per player.
    let game0 = await contract.startGame(

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

      {from: accounts[0]}
    )

    let game0Log = game0.logs[0].args;
    // console.log(game0Log);
    expect(game0Log.ticketTokenAddress).to.eql(token.address);
    expect(game0Log.feeAddress).to.eql(gameFeeAddress);
    expect(game0Log.gameNumber).to.be.bignumber.equal('0');
    expect(game0Log.feePercent).to.be.bignumber.equal(gameFeePercent);
    expect(game0Log.ticketPrice).to.be.bignumber.equal(ticketPrice);
    expect(game0Log.maxPlayers).to.be.bignumber.equal(maxPlayers);
    expect(game0Log.maxTicketsPlayer).to.be.bignumber.equal(maxTicketsPlayer);

    // Add additional game pot ERC20 asset
    let game0Pot1AssetValue = 5;
    let game0AddPotAsset0 = await contract.addGamePotERC20Asset(

      // Game number
      game0Log.gameNumber,

      // Asset address
      token.address,

      // Asset value
      web3.utils.toBN(game0Pot1AssetValue).mul(web3.utils.toBN(10).pow(decimals)),

      {from: accounts[0]}
    )

    let game0AddPotAsset0Log = game0AddPotAsset0.logs[0].args;
    // console.log(game0AddPotAsset0Log);
    // return;

    // Number of games increases by one
    expected = web3.utils.toBN('1');
    actual = await contract.totalGames({from: accounts[1]});
    expect(actual).to.be.bignumber.equal(expected);


    // Add first game pot ERC721 asset
    let game0AddPotAsset1 = await contract.addGamePotERC721Asset(

      // Game number
      game0Log.gameNumber,

      // Asset address
      nftERC721.address,

      // Asset value
      nftERC721Asset0.logs[0].args.tokenId,

      {from: accounts[0]}
    )

    // let game0AddPotAsset1Log = game0AddPotAsset1.logs[0].args;
    // console.log(game0AddPotAsset1Log);
    // return;



    // Add second game pot ERC721 asset
    // let game0AddPotAsset2 = await contract.addGamePotERC721Asset(

    //   // Game number
    //   game0Log.gameNumber,

    //   // Asset value
    //   nftERC721Asset1.logs[0].args.tokenId,

    //   // Asset address
    //   nftERC721.address,

    //   {from: accounts[0]}
    // )

    // // let game0AddPotAsset2Log = game0AddPotAsset2.logs[0].args;
    // // console.log(game0AddPotAsset2Log);
    // // return;

    // // Check NFT one is owned by contract
    // let nftERC721Asset1OwnerAfterAdding = await nftERC721.ownerOf.call(
    //   nftERC721Asset1.logs[0].args.tokenId,
    //   {from: accounts[0]}
    // );
    // // console.log(nftERC721Asset1OwnerAfterAdding);
    // expect(nftERC721Asset1OwnerAfterAdding).to.be.bignumber.equal(contract.address);

    // // Remove NFT one from game, back to A0
    // let game0AddPotAsset2Remove = await contract.removeGamePotERC721Asset(

    //   // Game number
    //   game0Log.gameNumber,

    //   // Asset value
    //   nftERC721Asset1.logs[0].args.tokenId,

    //   // Asset address
    //   nftERC721.address,

    //   {from: accounts[0]}
    // )

    // // Check NFT one is back to A0 owner
    // let nftERC721Asset1OwnerAfterRemoval = await nftERC721.ownerOf.call(
    //   nftERC721Asset1.logs[0].args.tokenId,
    //   {from: accounts[0]}
    // );
    // // console.log(nftERC721Asset0Owner);
    // expect(nftERC721Asset1OwnerAfterRemoval).to.be.bignumber.equal(accounts[0]);


    // // Check game zero pot states - for removal of game pot asset
    // let game0State = await contract.getGameState.call(
    //   game0Log.gameNumber,
    //   {from: accounts[1]}
    // );

    // // Check gamepot asset three, is now null
    // expect(game0State.pot[3].assetAddress).to.eql('0x0000000000000000000000000000000000000000');
    // // console.log(game0State.pot);
    // // return;


    // Add ERC1155 (NFT) game pot asset
    let game0AddPotAssetERC1155 = await contract.addGamePotERC1155Asset(

      // Game number
      game0Log.gameNumber,

      // Asset address
      nftERC1155.address,

      // Asset ID
      nftERC1155Asset0.logs[0].args.id,

      // Asset amount
      web3.utils.toBN('1'),

      // Asset data
      '0x0',

      {from: accounts[0]}
    )

    // let game0AddPotAssetERC1155Log = game0AddPotAssetERC1155.logs[0].args;
    // console.log(game0AddPotAssetERC1155Log);
    // return;



    // Approve and buy 1 ticket for A1
    let game0A1Ticket = await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[1]}
    )

    let game0A1TicketLog = game0A1Ticket.logs[0].args;
    // console.log(game0A1TicketLog);
    expect(game0A1TicketLog.playerAddress).to.be.bignumber.equal(accounts[1]);
    expect(game0A1TicketLog.gameNumber).to.be.bignumber.equal('0');
    expect(game0A1TicketLog.playerCount).to.be.bignumber.equal('1');
    expect(game0A1TicketLog.ticketCount).to.be.bignumber.equal(numberOfTickets);

    // Check contract balance (pot)
    let contractBalance = await token.balanceOf.call(contract.address, {from: accounts[1]});
    // console.log(contractBalance.toString());

    expect(contractBalance).to.eql(web3.utils.toBN(
      10 + game0Pot1AssetValue
    ).mul(web3.utils.toBN(10).pow(decimals)));

    // Buy second ticket for A1 (should fail)
    try {
      await contract.buyTicket(
      
        // Game number
        game0Log.gameNumber,
        
        // Number of tickets
        numberOfTickets,
        
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
    await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[2]}
    )

    // Approve and buy 1 ticket for A3
    await contract.buyTicket(
      
      // Game number
      game0Log.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[3]}
    )
    
    // Buy 1 ticket for A4 (should fail)
    try {
      await contract.buyTicket(
      
        // Game number
        game0Log.gameNumber,
        
        // Number of tickets
        numberOfTickets,
        
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

    // Store current balances for winner game pot receipt checks
    let playersWithBalance = [];
    for (let i = 0; i < accounts.length; i++) {
      playersWithBalance[accounts[i]] = await token.balanceOf.call(accounts[i], {from: accounts[i]});
    }

    // Check active game list
    let activeGamesBeforeEnd = await contract.getActiveGames.call(10, {from: accounts[1]});
    // console.log(activeGamesBeforeEnd);
    activeGamesBeforeEnd.forEach((ticket, index) => {
      // console.log('activeGamesBeforeEnd: ' + index + ': ' + ticket)
    });
    // return;




    // End game zero. Choose a random winner
    let game0EndGame = await contract.endGame(
      
      // Game number
      game0Log.gameNumber,
      
      {from: accounts[0]}
    );

    let game0EndGameLog = game0EndGame.logs[0].args;
    // console.log(game0EndGameLog);
    // expect(game0EndGameLog.winnerAddress).to.eql(accounts[1]);
    expect(game0EndGameLog.gameNumber).to.be.bignumber.equal('0');

    expect(game0EndGameLog.pot[0].value).to.be.bignumber.equal(web3.utils.toBN((ticketPrice * numberOfTickets) * 3));
    expect(game0EndGameLog.pot[0].assetType).to.be.bignumber.equal('0');
    expect(game0EndGameLog.pot[0].assetAddress).to.eql(token.address);

    expect(game0EndGameLog.pot[1].value).to.be.bignumber.equal(web3.utils.toBN(game0Pot1AssetValue).mul(web3.utils.toBN(10).pow(decimals)));
    expect(game0EndGameLog.pot[1].assetType).to.be.bignumber.equal('0');
    expect(game0EndGameLog.pot[1].assetAddress).to.eql(token.address);

    expect(game0EndGameLog.pot[2].value).to.be.bignumber.equal(nftERC721Asset0.logs[0].args.tokenId);
    expect(game0EndGameLog.pot[2].assetType).to.be.bignumber.equal('1');
    expect(game0EndGameLog.pot[2].assetAddress).to.eql(nftERC721.address);

    expect(game0EndGameLog.pot[3].value).to.be.bignumber.equal(nftERC1155Asset0.logs[0].args.id);
    expect(game0EndGameLog.pot[3].assetType).to.be.bignumber.equal('2');
    expect(game0EndGameLog.pot[3].assetAddress).to.eql(nftERC1155.address);

    // Number of games ended increases by one
    expected = web3.utils.toBN('1');
    actual = await contract.totalGamesEnded({from: accounts[1]});
    expect(actual).to.be.bignumber.equal(expected);

    // Check winner is owner of pot two NFT
    let nftERC721Asset0Owner = await nftERC721.ownerOf.call(
      nftERC721Asset0.logs[0].args.tokenId,
      {from: accounts[0]}
    );
    // console.log(nftERC721Asset0Owner);
    expect(nftERC721Asset0Owner).to.be.bignumber.equal(game0EndGameLog.winnerAddress);

    // Check winner token balance from pot zero and one
    let game0WinnerBalance = await token.balanceOf.call(game0EndGameLog.winnerAddress, {from: accounts[0]});

    let winnerBalanceBeforeGameEnd = web3.utils.toBN(playersWithBalance[game0EndGameLog.winnerAddress]).div(web3.utils.toBN(10).pow(decimals)).toNumber();
    // console.log('winnerBalanceBeforeGameEnd: ' + winnerBalanceBeforeGameEnd);

    let winnerBalanceAfterGameEnd = web3.utils.toBN(game0WinnerBalance).div(web3.utils.toBN(10).pow(decimals)).toNumber();
    // console.log(winnerBalanceAfterGameEnd);
    // console.log(ticketPrice.div(web3.utils.toBN(10).pow(decimals)).toNumber());
    // console.log(numberOfTickets.toNumber() * 3);
    // console.log(game0Pot1AssetValue);

    // Deduct all ERC20 pots to match previous account balance (this game has no fee to calc)
    expect(winnerBalanceBeforeGameEnd).to.eql(
      winnerBalanceAfterGameEnd
      - ((ticketPrice.div(web3.utils.toBN(10).pow(decimals)).toNumber() * numberOfTickets.toNumber()) * 3) // Tickets (pot zero)
      - game0Pot1AssetValue // Additional game pot asset (pot two)
    );

    // Check game zero states
    game0State = await contract.getGameState.call(
      game0EndGameLog.gameNumber,
      {from: accounts[1]}
    );

    // Needs fee offset calc
    expect(game0State.status).to.be.bignumber.equal('0');
    
    expect(game0State.playerCount).to.be.bignumber.equal(web3.utils.toBN('3'));
    // Each player bought one ticket each
    expect(game0State.ticketCount).to.be.bignumber.equal(web3.utils.toBN('30'));
    expect(game0State.maxPlayers).to.be.bignumber.equal(maxPlayers);
    expect(game0State.maxTicketsPlayer).to.be.bignumber.equal(maxTicketsPlayer);
    expect(game0State.ticketPrice).to.be.bignumber.equal(ticketPrice);
    expect(game0State.feeAddress).to.be.bignumber.equal(gameFeeAddress);

    expect(game0State.pot[0].value).to.be.bignumber.equal(web3.utils.toBN((ticketPrice * numberOfTickets) * 3));
    expect(game0State.pot[0].assetType).to.be.bignumber.equal('0');
    expect(game0State.pot[0].assetAddress).to.eql(token.address);

    expect(game0State.pot[1].value).to.be.bignumber.equal(web3.utils.toBN(game0Pot1AssetValue).mul(web3.utils.toBN(10).pow(decimals)));
    expect(game0State.pot[1].assetType).to.be.bignumber.equal('0');
    expect(game0State.pot[1].assetAddress).to.eql(token.address);

    expect(game0State.pot[2].value).to.be.bignumber.equal(nftERC721Asset0.logs[0].args.tokenId);
    expect(game0State.pot[2].assetType).to.be.bignumber.equal('1');
    expect(game0State.pot[2].assetAddress).to.eql(nftERC721.address);

    // Check all game zero player states
    let game0PlayerState = [];
    let game0TicketIndex = 0;
    for (let i = 0; i < accounts.length; i++) {

      // Only need to check the players of `buyTicket` above
      if (i < 1 || i > 3) continue;

      // console.log(i + ': ' + accounts[i]);

      game0PlayerState = await contract.getGamePlayerState.call(
        game0EndGameLog.gameNumber,
        accounts[i],
        {from: accounts[i]}
      );
      // console.log(game0PlayerState.length);

      expect(game0PlayerState.length).to.eql(numberOfTickets.toNumber());

      for (let j = 0; j < game0PlayerState.length; j++) {
        // console.log(j + ': ' + game0PlayerState[j].toNumber());
        expect(game0PlayerState[j].toNumber()).to.eql(game0TicketIndex);
        game0TicketIndex++;
      }
    }


    maxPlayers = web3.utils.toBN('3');
    maxTicketsPlayer = web3.utils.toBN('2');
    gameFeePercent = web3.utils.toBN('3'); // 1%
    ticketPrice = web3.utils.toBN('1').mul(web3.utils.toBN(10).pow(decimals));
    numberOfTickets = web3.utils.toBN('1');
    gameFeeAddress = accounts[5];

    // Start game for GameBobToken, exactly two token per entry,
    // max three players, max two tickets per player.
    let game1StartGame = await contract.startGame(

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

      {from: accounts[0]}
    );

    let game1StartGameLog = game1StartGame.logs[0].args;
    // console.log(game1StartGameLog);

    // Another game test run, buying two tickets each
    count = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[1]}
    );
    count2 = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[2]}
    );
    count3 = await contract.buyTicket(
      
      // Game number
      game1StartGameLog.gameNumber,
      
      // Number of tickets
      numberOfTickets,
      
      {from: accounts[3]}
    );

    contractBalance = await token.balanceOf.call(accounts[1], {from: accounts[1]});


    // Check active game list
    let activeGamesBeforeGame1End = await contract.getActiveGames.call(2, {from: accounts[1]});
    // console.log(activeGamesBeforeGame1End);
    activeGamesBeforeGame1End.forEach((ticket, index) => {
      // console.log('activeGamesBeforeGame1End: ' + index + ': ' + ticket)
    });
    // return;

    await contract.endGame(
      game1StartGameLog.gameNumber,
      {from: accounts[0]}
    );

    // contractBalance = await token.balanceOf.call(contract.address, {from: accounts[1]});
    // console.log(contractBalance.toString());

    // expect(contractBalance).to.eql(web3.utils.toBN('0').mul(web3.utils.toBN(10).pow(decimals)));

    // contractBalance = await token.balanceOf.call(accounts[1], {from: accounts[1]});
    // console.log('after end: ' + contractBalance.toString());
    // expect(contractBalance).to.eql(web3.utils.toBN('9991910000000000000000'));

    // contractBalance = await token.balanceOf.call(accounts[2], {from: accounts[2]});
    // console.log(contractBalance.toString());
    // expect(contractBalance).to.eql(web3.utils.toBN('10001000000000000000000'));

    contractBalance = await token.balanceOf.call(gameFeeAddress, {from: accounts[2]});
    // console.log('after fee: ' + contractBalance.toString());
    expect(contractBalance).to.eql(web3.utils.toBN('90000000000000000'));
    
  });
});