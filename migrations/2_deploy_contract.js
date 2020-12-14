const { toWei } = require("web3-utils");

const Trade = artifacts.require("Trade");
const MockERC20 = artifacts.require("MockERC20");
const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");

module.exports = async function (deployer, network, accounts) {
  let OWNER = accounts[0];

  let WETH;
  let factory;
  let router2;

  if ("mainnet" === network) {
    factory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    router2 = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  } else
  if ("rinkeby" === network) {
    factory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    router2 = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  } else
  if ("development" === network) {
    WETH = await MockERC20.new('WETH', 'WETH', toWei('100000000'), { from: OWNER });
    const factoryInstance = await UniswapV2Factory.new(OWNER, { from: OWNER });
    const router2Instance = await UniswapV2Router02.new(factoryInstance.address, WETH.address, { from: OWNER });
    factory = factoryInstance.address
    router2 = router2Instance.address
  } else {
    throw new Error("Not configured")
  }

  await deployer.deploy(Trade, factory, router2);
};
