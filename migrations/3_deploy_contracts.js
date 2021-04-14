const { toWei } = require("web3-utils");

const MockERC20 = artifacts.require("MockERC20");
const FirstTradingToken = artifacts.require("FirstTradingToken");
const SecondTradingToken = artifacts.require("SecondTradingToken");
const Trade = artifacts.require("Trade");
const MockedTrade = artifacts.require("MockedTrade");
const UniswapV2FactoryJson = require("@uniswap/v2-core/build/UniswapV2Factory");
const UniswapV2Router02Json = require("@uniswap/v2-periphery/build/UniswapV2Router02");
const UniswapV2PairJson = require("@uniswap/v2-core/build/UniswapV2Pair");

const contract = require('@truffle/contract');

const UniswapV2Factory = contract(UniswapV2FactoryJson);
const UniswapV2Router02 = contract(UniswapV2Router02Json);
const UniswapV2Pair = contract(UniswapV2PairJson);

UniswapV2Factory.setProvider(this.web3._provider);
UniswapV2Router02.setProvider(this.web3._provider);
UniswapV2Pair.setProvider(this.web3._provider);


module.exports = async function (deployer, network, accounts) {
  let factory;
  let router;
  let OWNER = accounts[0];
  if ("mainnet" === network) {
    factory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    router = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  } else if ("bscMainnet" === network) {
    factory = '0xBCfCcbde45cE874adCB698cC183deBcF17952812';
    router = '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F';
  } else {
    const liquidityAmount = toWei('100000');
    const WETH = await MockERC20.deployed();
    const firstToken = await FirstTradingToken.deployed();
    const secondToken = await SecondTradingToken.deployed();
    await deployer.deploy(UniswapV2Factory, OWNER, { from: OWNER });
    const factoryInstance = await UniswapV2Factory.deployed();
    await deployer.deploy(UniswapV2Router02, factoryInstance.address, WETH.address, { from: OWNER });
    const routerInstance = await UniswapV2Router02.deployed();
    const paths = [
      [(WETH), (firstToken)],
      [(WETH), (secondToken)],
      [(firstToken), (secondToken)]
    ];
    for (const path of paths) {
      await factoryInstance.createPair(...path.map(token => token.address), { from: OWNER });
      for (const token of path) await token.approve(routerInstance.address, liquidityAmount, { from: OWNER });
      const deadline = (await web3.eth.getBlock('latest')).timestamp + 10000;
      await routerInstance.addLiquidity(
        path[0].address,
        path[1].address,
        liquidityAmount,
        liquidityAmount,
        '1',
        '1',
        OWNER,
        deadline,
        { from: OWNER }
      );
    }
    factory = factoryInstance.address;
    router = routerInstance.address;
    if (["development", "soliditycoverage"].includes(network)) {
      await deployer.deploy(MockedTrade, factory, router);
    }
  }
  await deployer.deploy(Trade, factory, router);

};
