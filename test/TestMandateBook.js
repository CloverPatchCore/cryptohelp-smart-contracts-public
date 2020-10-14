const MandateBook = artifacts.require('./MandateBook');
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

contract('MandateBook', (accounts) => {

  const OWNER = accounts[0];
  const INVESTOR1 = accounts[1];
  const INVESTOR2 = accounts[2];
  const MANAGER1 = accounts[3];
  const MANAGER2 = accounts[4];
  const OUTSIDER = accounts[5];

  let mandateBook;

  before('setup', async () => {
    mandateBook = await MandateBook.deployed();
  });

  afterEach('revert', async () => {
    //
  });

/* -------------------------
-------------------------
-------------------------
-------------------------
*/

  describe('Mandate LifeCycle Steps', async () => {
    
    /* ------------------------- */
    let tx;

    it('Investor should be able to create a Mandate', async () => {
      /* first transaction to have zero index */
      tx = await mandateBook.createMandate(
        MANAGER1 /* investor */, 
        0 /* TODO set nonzero duration later */, 
        30/* takeProfit */, 
        20/* stopLoss */, 
        {from:INVESTOR1})
      });

    it('.. emitting the CreateMandate event', async () => {
      expectEvent(tx, 'CreateMandate', {id: toBN(0), ethers: toBN(0), investor: INVESTOR1, manager: MANAGER1, duration: toBN(0), takeProfit: toBN(30), stopLoss: toBN(20)})
    });
    
    it('Investor should be able to populate a Mandate');
    it('Investor should be able to submit a Mandate to a Manager');
    it('Manager should be able to accept the Mandate appointed by the Investor');
    it('Manager should be able to decline the Mandate appointed by the Investor');
    it('Investor should be able to deposit ethers to the Mandate before it\'s started');
    it('Manager should be able to deposit ethers as coollateral to the Mandate before it\'s started');
    it('Manager should be able to start the Mandate that they accepted before');
    it('Manager should be able to start the Mandate submitted to them by Investor');
    it('Manager should be able to close in profit Mandate');
    it('Manager should be able to close through the stoploss');
    it('Investor should be able to close through the stoploss');
    it('Manager should be able to settle the deal distributing the earnings');
    it('Investor should be able to settle the deal distributing the earnings');

  });
  describe('Access Violations Checks', async () => {});
})