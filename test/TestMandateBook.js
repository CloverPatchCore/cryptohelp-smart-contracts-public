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

  describe('Agreement Creation Phase', async () => {
    let txA;
    it('Manager should be able to create an Agreement with terms', async () => {
     txA = await mandateBook.createAgreement(
        "0x6ee856ae55b6e1a249f04cd3b947141bc146273c", /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(0), /* collatAmount */
        30 * 24 * 3600,  /* duration   */
        7 * 24 * 3600, /* open period */ 
        {from:INVESTOR1})
      });

     /* it('.. emitting the CreateMandate event', async () => {
      expectEvent(txA, 'CreateMandate', {id: toBN(0), ethers: toBN(0), investor: INVESTOR1, manager: MANAGER1, duration: toBN(0), takeProfit: toBN(30), stopLoss: toBN(20)})
    });  */
    it('.. if the collateral allowance is not approved in the baseCoin ERC20, the Agreement should still be created ..');
    it('.. and the contract should try take maximum allowance .. ');
    it('.. and the event PendingCollateral to be emitted indicating the remaining amount');

    it('Manager should be able to deposit collateral in stablecoin to an Agreement');
        
    it('Manager should be able to (re)populate an Agreement with terms/edit');
    it(' .. whereas if the new collateral value is reduced, the collateral difference is being returned back on Manager ERC20 coin address');
    it('Manager should be able to set Agreement as published');
  });

  describe('Agreement Acceptance Phase', async () =>{
    it('Investor should be able to opt-in to the Agreement by depositing Capital in Stablecoins');
    it('.. in which case the Mandate is populated with the terms');
    it('Investor should be able to opt-out and withdraw Capital only before the end of Open Period of the Agreement');
    it('.. in which case the Mandate is being deleted');
    it('Investor should be able to opt-in to the Agreement by more than one Mandate depositing Capital in Stablecoins');
    it('.. in which case the new Mandate is populated with the new terms based on the FCFS collateral coverage principle');
    it('Manager cannot change the terms or decrease collateral on the Agreement');
    it('Manager should be able to withdraw the Agreement whatsoever');
    it('.. in which case Investors can withdraw their Committed Capital');
    // FTF
    // it('ability to set the limit on capital accepted');
  });

  describe('Agreement Trading Phase', async () => {
    it('Manager should be able to trade with Capital on UniSwap');
  });

  describe('Stopped Out Case', async () => {
    it('Investor should NOT be able to close the Mandate and withdraw the collateral assigned to Mandate');
  });
  describe('Closed In Profit Case', async () => {
    it('???Should the settlement happen earlier by the Manager initiative???')
  });
  describe('Settlement by Expiry Phase', async () => {
    it('Any of the parties may close all open trading positions on ???all the Mandates of the Agreement ||| their Mandate ??? and do the profit split based on the terms');
  });


    /* ------------------------- */
  //   let tx;

  //   it('Investor should be able to create a Mandate', async () => {
  //     /* first transaction to have zero index */
  //     tx = await mandateBook.createMandate(
  //       MANAGER1 /* investor */, 
  //       0 /* TODO set nonzero duration later */, 
  //       30/* takeProfit */, 
  //       20/* stopLoss */, 
  //       {from:INVESTOR1})
  //     });

  //   it('.. emitting the CreateMandate event', async () => {
  //     expectEvent(tx, 'CreateMandate', {id: toBN(0), ethers: toBN(0), investor: INVESTOR1, manager: MANAGER1, duration: toBN(0), takeProfit: toBN(30), stopLoss: toBN(20)})
  //   });
  // });
  describe('Access Violations Checks', async () => {});
})