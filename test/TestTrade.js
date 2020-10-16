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

const {
  takeSnapshot,
  revertToSnapshot,
  timeTravelTo
} = require("./helper");

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

contract('Trade', ([OWNER, MINTER, INVESTOR1, INVESTOR2, MANAGER1, MANAGER2, OUTSIDER]) => {
  
  let trade;
  let WETH, DAI, TKNX;

  beforeEach(async() => {
    this.snapshotId = await takeSnapshot();
  });

  afterEach('revert', async () => {
    await revertToSnapshot(this.snapshotId);
  });

  before('setup', async () => {
    WETH = await MockERC20.new('WETH', 'WETH', '100000000', { from: MINTER });
    DAI = await MockERC20.new('DAI', 'DAI', '100000000', { from: MINTER });
    TKNX = await MockERC20.new('TokenX', 'TKNX', '100000000000', { from: MINTER });
    trade = await Trade.new({ from: OWNER });
  });

  describe('Lock traders if investor getting big loss', async () => {
    it('Should be possible to lock trading by agreement', async () => {})
    it('Should not be possible to any trade if agreement is locked', async () => {})
  });

  describe('Swap ERC20 token to ERC20 token', async () => {
    it('Should be possible to create new exchange', async () => {})
    it('Should be possible to create 2 new exchanges', async () => {})
  });

  describe('Swap ETH to ERC20 token', async () => {
    it('Should be possible to create new exchange', async () => {})
  });

  describe('Swap ERC20 token to ETH', async () => {
    it('Should be possible to create new exchange', async () => {})
  });
})