const MandateBook = artifacts.require("MandateBook");

module.exports = function (deployer) {
  deployer.deploy(MandateBook);
};
