const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { BN, toBN, toChecksumAddress } = web3.utils;
const { Contract, constants } = require('ethers');
const { MockProvider } = require("ethereum-waffle");
require('dotenv').config();
require("chai").use(require("chai-bn")(BN)).should();

const Trade = artifacts.require('./Trade');
const MockERC20 = artifacts.require('./MockERC20');
const UniswapV2Router02 = artifacts.require('./UniswapV2Router02');
const UniswapV2Factory = artifacts.require('./UniswapV2Factory');
const UniswapV2Pair = artifacts.require('./UniswapV2Pair');

const _require = require("app-root-path").require;
const BlockchainCaller = _require("/utils/blockchain_caller");

const chain = new BlockchainCaller(web3);
const { AddressZero, Zero, MaxUint256 } = constants;

// load env constants
const { MNEMONIC_PHRASE } = process.env;

const {
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");

const {
  takeSnapshot,
  revertToSnapshot,
  timeTravelTo,
  timeTravelToDate,
  timeTravelToBlock,
  expandTo18Decimals
} = require("./helper");

const provider = new MockProvider({
  hardfork: 'istanbul',
  mnemonic: MNEMONIC_PHRASE, //'horn horn horn horn horn horn horn horn horn horn horn horn',
  gasLimit: 9999999
})

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

// @notice function that wrap contract address to contract instance
function toContract(address, abi, provider=provider) {
  return new Contract(address, JSON.stringify(abi), provider);
}

// add liquidity for pair
async function addLiquidity({
  pair, // Contract
  wallet,  // Address
  overrides = 0,
  token0, // Contract
  token1, // Contract
  token0Amount = 0,
  token1Amount = 0
}, {
  from
}) {
  if (typeof pair === "string") {
    throw new Error('Pair: contract should be the instance');
  }

  await token0.transfer(toChecksumAddress(pair.address), token0Amount, { from: from })
  await token1.transfer(toChecksumAddress(pair.address), token1Amount, { from: from })
  await pair.mint(wallet, overrides, { from: from })
}

contract('Trade', ([OWNER, MINTER, INVESTOR1, INVESTOR2, MANAGER1, MANAGER2, OUTSIDER, TOKENHOLDER1, LPBALANCER]) => {
  let router;
  let factory;
  let trade;
  let mandateBook;

  let WETH,
    DAI,
    TKNX;

  let WETH_DAI = []
  let WETH_TKNX = []
  let DAI_TKNX = []

  const DURATION1 = toBN(30 * 24 * 3_600); // trading end date
  const HALFDURATION1 = toBN(15 * 24 * 3_600);
  const OPENPERIOD1 = toBN(7 * 24 * 3_600); // mandate accept end date
  const HALFOPENPERIOD1 = toBN(7 * 12 * 3_600);

  // beforeEach(async() => {
  //   this.snapshotId = await takeSnapshot();
  // });

  afterEach('revert', async () => {
    await revertToSnapshot(this.snapshotId);
  });

  before('setup', async () => {

    WETH = await MockERC20.new('WETH', 'WETH', toWei('100000000'), { from: MINTER });
    DAI = await MockERC20.new('DAI', 'DAI', toWei('100000000'), { from: MINTER });
    TKNX = await MockERC20.new('TokenX', 'TKNX', toWei('100000000000'), { from: MINTER });

    // creat pair WETHDAI
    WETH_DAI[0] = (WETH.address);
    WETH_DAI[1] = (DAI.address);

    // creat pair WETHTKNX
    WETH_TKNX[0] = (WETH.address);
    WETH_TKNX[1] = (TKNX.address);

    // creat pair DAITKNX
    DAI_TKNX[0] = (DAI.address);
    DAI_TKNX[1] = (TKNX.address);

    factory = await UniswapV2Factory.new(OWNER, { from: OWNER });
    router = await UniswapV2Router02.new(factory.address, WETH.address, { from: OWNER });

    trade = await Trade.new(factory.address, router.address, { from: OWNER });
    mandateBook = trade;

    this.snapshotId = await takeSnapshot();
  });

  describe('Trading', async () => {

    beforeEach(async () => {
      let result = await factory.createPair(...WETH_DAI);
      let pair = result.logs[0].args.pair;

      // await addLiquidity({
      //   pair: toContract(pair, UniswapV2Pair.abi, provider), // object
      //   wallet: MINTER,  // object
      //   overrides: 0,
      //   token0: WETH,
      //   token1: DAI,
      //   token0Amount: toWei('1'),
      //   token1Amount: toWei('350'),
      // }, { from: MINTER })

      // 0) investors and manager get moneys
      await DAI.transfer(MANAGER1, toWei(500_000), {from:MINTER});
      await DAI.transfer(INVESTOR1, toWei(150_000), {from:MINTER});
      await DAI.transfer(INVESTOR2, toWei(200_000), {from:MINTER});

      // 1) create agreement
      await trade.createAgreement(
        DAI.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        DURATION1,  /* duration   */
        OPENPERIOD1, /* open period */
        { from: MANAGER1 }
      );

      // 2) agreement going to the end
      //let's have IVNESTOR1 commit to Agreement
      await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
      //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
      await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), {from: INVESTOR1});
    })

    it('Should be possible to create new exchange', async () => {

      await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE

      let agreementId = 0,
        tokenIn = WETH.address,
        tokenOut = DAI.address,
        amountIn = 1,
        amountOutMin = 380,
        deadline = 0;

      await trade.swapTokenToToken(
        agreementId,
        tokenIn,
        tokenOut,
        amountIn,
        amountOutMin,
        deadline
      );
    });
  })

  describe('Closing of the agreement via "sellAll"', async () => {

    let agreementId = 0;

    beforeEach(async () => {

      // 0) investors and manager get moneys
      await DAI.transfer(MANAGER1, toWei(500_000), {from:MINTER});
      await DAI.transfer(INVESTOR1, toWei(150_000), {from:MINTER});
      await DAI.transfer(INVESTOR2, toWei(200_000), {from:MINTER});

      // 1) create agreement
      await trade.createAgreement(
        DAI.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        DURATION1,  /* duration   */
        OPENPERIOD1, /* open period */
        { from: MANAGER1 }
      );

      // 2) agreement going to the end
      //let's have IVNESTOR1 commit to Agreement
      await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
      //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
      await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), {from: INVESTOR1});
    })

    it('Should not be possible to close agreement before deadline', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE

      await expectRevert(trade.sellAll(agreementId), "Agreement active or closed");
    })

    it('Should not be possible to close agreement twice', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");

      await expectRevert(trade.sellAll(agreementId, { from: MANAGER1 }), "Agreement was closed");
    })

    it('Should not be possible to close agreement any other person, then manager', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");

      await expectRevert(trade.sellAll(agreementId, { from: MANAGER2 }), "Only appointed Fund Manager");
      await expectRevert(trade.sellAll(agreementId, { from: TOKENHOLDER1 }), "Only appointed Fund Manager");
    })

    it('Should be possible to close agreement, if manager has no trades', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal(
        String((await trade.balances(agreementId)).init),
        String((await trade.balances(agreementId)).counted),
        "After close balance not equal to initial"
      );
    })

    it('Should be possible to close agreement', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");
    })
  });

  describe('Closing of the agreement via "sell"', async () => {

    let agreementId = 0;
    let deadline = 5 * 60; // 5 minutes

    beforeEach(async () => {

      // 0) investors and manager get moneys
      await DAI.transfer(MANAGER1, toWei(500_000), {from:MINTER});
      await DAI.transfer(INVESTOR1, toWei(150_000), {from:MINTER});
      await DAI.transfer(INVESTOR2, toWei(200_000), {from:MINTER});

      // 1) create agreement
      await trade.createAgreement(
        DAI.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        DURATION1,  /* duration   */
        OPENPERIOD1, /* open period */
        { from: MANAGER1 }
      );

      // 2) agreement going to the end
      //let's have IVNESTOR1 commit to Agreement
      await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
      //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
      await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), {from: INVESTOR1});
    })

    it('Should not be possible to close agreement before deadline', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE

      await expectRevert(trade.sell(agreementId, { from: MANAGER1 }), "Agreement active or closed");
    })

    it('Should not be possible to close agreement twice', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");

      await expectRevert(trade.sellAll(agreementId, { from: MANAGER1 }), "Agreement was closed");
    })

    it('Should not be possible to close agreement any other person, then manager', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sellAll(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");

      await expectRevert(trade.sellAll(agreementId, { from: MANAGER2 }), "Only appointed Fund Manager");
      await expectRevert(trade.sellAll(agreementId, { from: TOKENHOLDER1 }), "Only appointed Fund Manager");
    })

    it('Should be possible to close agreement, if manager has no trades', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sell(agreementId, { from: MANAGER1 });

      assert.equal(
        String((await trade.balances(agreementId)).init),
        String((await trade.balances(agreementId)).counted),
        "After close balance not equal to initial"
      );
    })

    it('Should be possible to close agreement', async () => {
      await timeTravelTo(Number(OPENPERIOD1.toString()) + 1000);

      await trade.sell(agreementId, { from: MANAGER1 });

      assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");
    })
  });

  describe('Uniswap', async () => {

    beforeEach(async () => {
      await DAI.transfer(LPBALANCER, toWei(500_000), { from: MINTER });
      await WETH.transfer(LPBALANCER, toWei(500_000), { from: MINTER });
    })

    it('Should be possible create new pair', async () => {
      let result = await factory.createPair(...WETH_DAI);

      WETH_DAI;
      assert.equal(result.logs.length, 1);
      assert.equal(result.logs[0].event, 'PairCreated');
      assert.equal(result.logs[0].args[0], WETH_DAI[1]);
      assert.equal(result.logs[0].args[1], WETH_DAI[0]);
      assert.equal(result.logs[0].args[3].toString(), String(1));

      await expectRevert(factory.createPair(...WETH_DAI), "UniswapV2: PAIR_EXISTS")
    })

    it('Should be possible create new pair and make liquidity', async () => {
      let result = await factory.createPair(...WETH_DAI);
      let pair = result.logs[0].args.pair;

      await addLiquidity({
        pair: toContract(pair, UniswapV2Pair.abi, provider), // object
        wallet: TOKENHOLDER1,  // object
        overrides: 0,
        token0: WETH, // Contract
        token1: DAI,
        token0Amount: toWei(1),
        token1Amount: toWei(380),
      }, { from: TOKENHOLDER1 });
    })

    it('Should be possible get cumulative price', async () => {
      let {logs} = await factory.createPair(...WETH_DAI);
      let pairAddress = logs[0].args.pair;

      const pair = toContract(pairAddress, UniswapV2Pair.abi, provider);

      let token0 = await pair.token0();
      let token1 = await pair.token1();

      await token0.transfer(pair.address, expandTo18Decimals(10));
      await token1.transfer(pair.address, expandTo18Decimals(1000));

      // if oracle not responde
      // await expectRevert(trade.getPrice(WETH.address, DAI.address), "V20ORACLE: currentCumulativePrices call")

      let result = await trade.getPrice(WETH.address, DAI.address);
      //assert.m(calculatedAmount.toString(), expectedAmount, "calculated result has no expected value");
    })

  })

  // DONE
  describe('Counters and getters', async () => {
    it('Should be possible to get base asset', async () => {
      let agreementId = 0;

      await expectRevert(trade.getBaseAsset(agreementId), "Agreement not exist");

      await trade.createAgreement(
        DAI.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        DURATION1,  /* duration   */
        OPENPERIOD1, /* open period */
        { from: MANAGER1 }
      );

      let baseAsset = await trade.getBaseAsset(agreementId);

      assert.equal(baseAsset, DAI.address, "base asset lost");
    })
  });
})