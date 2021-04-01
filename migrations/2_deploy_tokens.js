const { toWei } = require("web3-utils");

const MockERC20 = artifacts.require("MockERC20");
const FirstTradingToken = artifacts.require("FirstTradingToken");
const SecondTradingToken = artifacts.require("SecondTradingToken");

module.exports = async function (deployer, network, accounts) {
  if (!["mainnet", "bscMainnet"].includes(network)) {
    const OWNER = accounts[0];
    const amount = toWei('1000000000');
    await deployer.deploy(MockERC20, 'WETH', 'WETH', amount, { from: OWNER });
    await deployer.deploy(FirstTradingToken, 'FirstToken', 'FT', amount, { from: OWNER });
    await deployer.deploy(SecondTradingToken, 'SecondToken', 'ST', amount, { from: OWNER });
  }
};
