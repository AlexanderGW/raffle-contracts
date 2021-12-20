const { expect, assert } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers');

// Load compiled artifacts
const Oracle = artifacts.require('Oracle');

// Start test block
contract('Oracle', function ([ creator, other ]) {
  let oracle;

  before(async function () {
    oracle = await Oracle.new();
  });

  it('has initial randomness', async function () {
    let rand = await oracle.rand();
    expect(rand).to.be.bignumber;
  });

  it('can change randomness', async function () {
    let rand1 = await oracle.rand();
    // console.log(rand1);
    expect(rand1).to.be.bignumber;
    await oracle.feedRandomness(Date.now());
    let rand2 = await oracle.rand();
    expect(rand2).to.be.bignumber;
    // console.log(rand2);
    assert(rand1 !== rand2, 'Randomness has changed');
  });
});