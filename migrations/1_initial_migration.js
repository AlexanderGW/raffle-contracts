const Oracle = artifacts.require("Oracle");
const GameMaster = artifacts.require("GameMaster");
const GameBobToken = artifacts.require("GameBobToken");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(Oracle).then(x => {
    return deployer.deploy(GameMaster, x.address).then(y => {
      return deployer.deploy(GameBobToken, accounts[0]) //y.address
    });
  });
};
