const { toWei } = require("web3-utils");

const Trade = artifacts.require("Trade");
const MockERC20 = artifacts.require("MockERC20");
const UniswapV2FactoryJson = require("@uniswap/v2-core/build/UniswapV2Factory");
const UniswapV2Router02Json = require("@uniswap/v2-periphery/build/UniswapV2Router02");

const contract = require('@truffle/contract');

const UniswapV2Factory = contract(UniswapV2FactoryJson);
const UniswapV2Router02 = contract(UniswapV2Router02Json);

UniswapV2Factory.setProvider(this.web3._provider);
UniswapV2Router02.setProvider(this.web3._provider);


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
  if (["development", "soliditycoverage"].includes(network)) {
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
