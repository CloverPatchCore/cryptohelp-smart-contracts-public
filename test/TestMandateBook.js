const MandateBook = artifacts.require('./MandateBook');
const ERC20 = artifacts.require('./MockERC20');
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
  timeTravelTo,
  timeTravelToBlock
} = require("./helper");

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

contract('MandateBook', (accounts) => {

  const OWNER = accounts[0];
  const INVESTOR1 = accounts[1];
  const INVESTOR2 = accounts[2];
  const MANAGER1 = accounts[3];
  const MANAGER2 = accounts[4];
  const OUTSIDER = accounts[5];
  const MINTER = accounts[6];

//  enum AgreementLifeCycle {
  const A_EMPTY = 0; // newly created and unfilled with data
  const A_POPULATED = 1; // filled with data
  const A_PUBLISHED = 2; // terms are solidified and Investors may now commit capital, TODO discuss rollback for the future
  const A_ACTIVE = 3; // trading may happen during this phase; no status transition backwards allowed
  const A_STOPPEDOUT = 4; //RESERVED
  const A_CLOSEDINPROFIT = 5; // the Agreement has been  prematurely closed by Manager in profit
  const A_EXPIRED = 6; //the ACTIVE period has been over now
  const A_SETTLED = 7;// All Investors and a Manager have withdrawn their yields / collateral

  const DURATION1 = /* toBN(10 * 60); */ 600;
  const HALFDURATION1 = /* toBN(5 * 60); */ 300;
  const OPENPERIOD1 = /* toBN(8 * 60); */ 480;
  const HALFOPENPERIOD1 = /* toBN(4 * 60); */ 240;

  let mandateBook;
  let iA;
  let txA;

  let bPound, bYen, bHryvna;

  before('setup', async () => {
    mandateBook = await MandateBook.deployed();

    // deploy a couple of funny stablecoins to use as capital and collateral
    bPound = await ERC20.new('BPound', 'bLBP', toWei(1_000_000), {from: MINTER});
    bYen = await ERC20.new('BYen', 'bY', toWei(500_000), {from: MINTER});
    bHryvna = await ERC20.new('BHryvna', 'bUAH', toWei(250_000), {from: MINTER});

    await bPound.transfer(MANAGER1, toWei(500_000), {from:MINTER});
    await bPound.transfer(INVESTOR1, toWei(150_000), {from:MINTER});
    await bPound.transfer(INVESTOR2, toWei(200_000), {from:MINTER});


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
    it('Manager should be able to create an Agreement with basic terms', async () => {
      //let's have MANAGER1 allow some coins for the MandateBook
      await bPound.approve(mandateBook.address, toWei(70_000), {from:MANAGER1});

      txA = await mandateBook.createAgreement(
        bPound.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        toBN(DURATION1),  /* duration   */
        toBN(OPENPERIOD1), /* open period */ 
        {from:MANAGER1});
      iA = 0;
      });

    it('.. even with insufficient amount ..', async () => {
      (await mandateBook.getAgreementCollateral(toBN(0))).should.be.bignumber.eq(toWei(70_000));
    });


    it('.. emitting the CreateAgreement event', async () => {
      expectEvent(txA, 'CreateAgreement', 
      {
        agreementID: toBN(iA),
        manager: toChecksumAddress(MANAGER1),
        baseCoin: bPound.address,
        targetReturnRate: toBN(30),
        maxCollateralRateIfAvailable: toBN(80),
        __collatAmount: toWei(70_000),
        __committedCapital: toBN(0),
        duration: toBN(DURATION1),
        openPeriod: toBN(OPENPERIOD1),
        publishTimestamp: toBN(0)
      });
    });
    it('.. if the collateral allowance is not approved in the baseCoin ERC20, the Agreement should still be created ..');
    it('.. and the contract should try take maximum allowance .. ');
    it('.. and the event PendingCollateral to be emitted indicating the remaining amount');

    it('Manager should be able to make more deposits of collateral in stablecoin to an Agreement, for example one with sufficient allowance', async () => {
      //let's approve some more funds and try to deposit twice
      await bPound.approve(mandateBook.address, toWei(150_000), {from:MANAGER1});
    });
    it('and one more with insufficient allowance of 50_000', async () => {
      //additional 100_000 collateral commitment this time
      await mandateBook.depositCollateral(toBN(0), toWei(100_000), {from:MANAGER1});
      //Manager will try to put 100_000, out of which 50_000 pass through
    });
    it('.. thus the total collateral should end up being 70k+100k+50K = 220k', async () => {
      await mandateBook.depositCollateral(toBN(0), toWei(100_000), {from:MANAGER1});
      (await mandateBook.getAgreementCollateral(toBN(0))).should.be.bignumber.eq(toWei(220_000));
    }); 
        
    it('Manager should be able to (re)populate an Agreement with terms/edit');
    it('.. whereas if the new collateral value is reduced, the collateral difference is being returned back on Manager ERC20 coin address');
    it('Manager should be able to set Agreement as published', async () => {
      txA = await mandateBook.publishAgreement(toBN(0), {from: MANAGER1});

    });
/*     it('.. emitting PublishAgreement Event', async () => {
      var theblock = await web3.eth.getBlock(txA.blockNumber.toString);
      expectEvent(txA, 'PublishAgreement', 
      {
        agreementID: toBN(0),
        manager: toChecksumAddress(MANAGER1),
        baseCoin: toChecksumAddress(base1),
        targetReturnRate: toBN(30),
        maxCollateralRateIfAvailable: toBN(80),
        __collatAmount: toBN(0),
        __committedCapital: toBN(0),
        duration: toBN(30 * 24 * 3600),
        openPeriod: toBN(7 * 24 * 3600),
        publishTimestamp: theblock.timestamp
      });
    });
 */  });

  describe('Agreement Acceptance Phase', async () =>{
    it('Investors should be able to opt-in to the Agreement by depositing Capital in Stablecoins', async () => {
      //let's have IVNESTOR1 and INVEESTOR2 commit to Agreement 
      await bPound.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
      //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
      await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), toWei(0), {from: INVESTOR1});
      //now let's introduce 1 more investor
      await bPound.approve(mandateBook.address, toWei(10_000), {from: INVESTOR2});
      await mandateBook.commitToAgreement(toBN(0), toWei(5_000), toWei(0), {from: INVESTOR2});
      (await mandateBook.getAgreementCommittedCapital(toBN(0))).should.be.bignumber.eq(toWei(35_000));
      //await sleep((OPENPERIOD1 + 1) * 1000);
      await timeTravelTo(OPENPERIOD1);

    });
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
    it('Right after the Open Period is over, Manager should be able to ONLY ONCE Start Agreement', async () => {
      await mandateBook.activateAgreement(toBN(0), {from: MANAGER1});
      (await mandateBook.getAgreementStatus(toBN(0), {from: OUTSIDER})).should.be.bignumber.eq(toBN(A_ACTIVE));
    });
    it('The Agreement should remain active throughout the DURATION', async () => {
      await timeTravelTo(HALFDURATION1);
      //await sleep(HALFDURATION1 * 1000);
      //TODO check if it reverts if we try to close or settle
    });
    it('FUTURE: Right after the Open Period is over, Manager should be able to ONLY  ONCE Cancel Agreement upon his discretion, for example if not enough Capital was committed');
    it('Manager should be able to trade with Capital on UniSwap');
  });

  describe('FUTURE: Stopped Out Case', async () => {
    it('Investor should NOT be able to close the Mandate and withdraw the collateral assigned to Mandate');
  });
  describe('FUTURE: Closed In Profit Case', async () => {
    it('Should the settlement happen earlier by the Manager initiative?');
  });
  describe('Settlement by Expiry Phase', async () => {
    //this should be enough for get outside of DURATION
    //await(HALFDURATION1+2000); //will be total duration plus 2 seconds
    it('Anyone can trigger the expiry of the contract and start settlement', async () => {
      await timeTravelTo(HALFDURATION1+100);
      await mandateBook.setExpiredAgreement(toBN(0));
      (await mandateBook.getAgreementStatus(toBN(0))).should.be.bignumber.eq(toBN(A_EXPIRED));
    });
    it('Mandate Agreement Manager or Mandate Investor should be able to settle the Mandate', async () => {
      let finalBal = toWei(35_000);
      
      inv1PreBal = await bPound.balanceOf(INVESTOR1);
      mgr1PreBal = await bPound.balanceOf(MANAGER1);
      await mandateBook.settleMandate(toBN(0), /* toWei(35_000) ,*/ {from: INVESTOR1});
      inv1EndBalShouldBe = toWei(150_000 /* initial balance */- 30_000 /* what he put in */+ 39_000); // 30_000 X 130%
      mgr1EndBalShouldBe = toWei(500_000 - (70_000 + 100_000 + 50_000) + (80 * 30_000 / 100) /* that's how much collateral was allocated to the mandate */ - (39_000 - 30_000) /* this is the lack of profit that has to be compensated */);
      (await bPound.balanceOf(INVESTOR1)).should.be.bignumber.eq(inv1EndBalShouldBe);
      (await bPound.balanceOf(MANAGER1)).should.be.bignumber.eq(mgr1EndBalShouldBe);

    });
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