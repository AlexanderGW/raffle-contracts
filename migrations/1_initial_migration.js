const Oracle = artifacts.require("Oracle");
const LottoGame = artifacts.require("LottoGame");
const LottoToken = artifacts.require("LottoToken");

module.exports = function (deployer) {
  deployer.deploy(Oracle).then(x => {
    deployer.deploy(LottoGame, x.address).then(y => {
      deployer.deploy(LottoToken, y.address)
    });
  });
};
