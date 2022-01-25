const Oracle = artifacts.require("Oracle");
const LottoGame = artifacts.require("LottoGame");
const LottoToken = artifacts.require("LottoToken");

module.exports = function (deployer) {
  deployer.deploy(Oracle).then(x => {
    return deployer.deploy(LottoGame, x.address).then(y => {
      return deployer.deploy(LottoToken, y.address)
    });
  });
};
