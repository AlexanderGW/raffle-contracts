const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers');

// Load compiled artifacts
const LottoToken = artifacts.require('LottoToken');

// Start test block
contract('LottoToken', function ([ creator, other ]) {
  const decimals = 18;
  const NAME = 'LottoToken';
  const SYMBOL = 'LPT';
  const TOTAL_SUPPLY = web3.utils.toBN('1000000000000000000000000000');
  //const TOTAL_SUPPLY = web3.utils.toBN('1000000000').mul(web3.utils.toBN(10).pow(decimals));

  beforeEach(async function () {
    this.token = await LottoToken.new(creator, { from: creator });
  });

  it('returns a value previously stored', async function () {
    // Use large integer comparisons
    expect(await this.token.totalSupply()).to.be.bignumber.equal(TOTAL_SUPPLY);
  });

  it('has a name', async function () {
    expect(await this.token.name()).to.be.equal(NAME);
  });

  it('has a symbol', async function () {
    expect(await this.token.symbol()).to.be.equal(SYMBOL);
  });

  it('assigns the initial total supply to the creator', async function () {
    expect(await this.token.balanceOf(creator)).to.be.bignumber.equal(TOTAL_SUPPLY);
  });
});