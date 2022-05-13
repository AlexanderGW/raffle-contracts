const Oracle = artifacts.require("Oracle");
const LottoGame = artifacts.require("LottoGame");
const GameBobToken = artifacts.require("GameBobToken");

module.exports = function (deployer) {
  deployer.deploy(Oracle).then(x => {
    return deployer.deploy(LottoGame, x.address).then(y => {
      return deployer.deploy(GameBobToken, y.address)
    });
  });
};
