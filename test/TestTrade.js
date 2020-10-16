const Trade = artifacts.require('./Trade');
const MockERC20 = artifacts.require('./MockERC20');
const _require = require("app-root-path").require;
const BlockchainCaller = _require("/utils/blockchain_caller");

const chain = new BlockchainCaller(web3);
const { BN, toBN, toChecksumAddress } = web3.utils;
require("chai").use(require("chai-bn")(BN)).should();


const {
  constants,
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

contract('Trade', ([OWNER, MINTER, INVESTOR1, INVESTOR2, MANAGER1, MANAGER2, OUTSIDER]) => {
  
  let trade;

  before('setup', async () => {
    this.weth = await MockERC20.new('WETH', 'WETH', '100000000', { from: MINTER });
    this.dai = await MockERC20.new('DAI', 'DAI', '100000000', { from: MINTER });
    this.tokenX = await MockERC20.new('TokenX', 'TKNX', '100000000', { from: MINTER });
    trade = await Trade.new({ from: OWNER });
  });

  afterEach('revert', async () => {
    //
  });

  describe('Swap ERC20 token to ERC20 token', async () => {
    //
  });

  describe('Swap ETH to ERC20 token', async () => {
    //
  });

  describe('Swap ERC20 token to ETH', async () => {
    //
  });
})