const Oracle = artifacts.require("Oracle");
const GameMaster = artifacts.require("GameMaster");
const GameBobToken = artifacts.require("GameBobToken");
const GameTrophyERC721 = artifacts.require("GameTrophyERC721");
const GameTrophyERC1155 = artifacts.require("GameTrophyERC1155");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(GameTrophyERC721)
  deployer.deploy(GameTrophyERC1155)
  deployer.deploy(Oracle).then(x => {
    return deployer.deploy(GameMaster, x.address).then(y => {
      return deployer.deploy(GameBobToken, accounts[0])
    });
  });
};
