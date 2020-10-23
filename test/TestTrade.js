const Web3 = require("web3");

const {web3} = require("@openzeppelin/test-helpers/src/setup");
const Trade = artifacts.require('./Trade');
const MockERC20 = artifacts.require('./MockERC20');

const UniswapV2Router02 = artifacts.require('./UniswapV2Router02');
const UniswapV2Factory = artifacts.require('./UniswapV2Factory');
const UniswapV2Pair = artifacts.require('./UniswapV2Pair');

const _require = require("app-root-path").require;
const BlockchainCaller = _require("/utils/blockchain_caller");

const chain = new BlockchainCaller(web3);
const { BN, toBN, toChecksumAddress } = web3.utils;


require("chai").use(require("chai-bn")(BN)).should();

const { Contract } = require('ethers');

require('dotenv').config();

// load env constants
const { MNEMONIC_PHRASE, PORT } = process.env;

const {
  constants,
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

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

contract('Trade', ([OWNER, MINTER, INVESTOR1, INVESTOR2, MANAGER1, MANAGER2, OUTSIDER]) => {
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

  const DURATION1 = toBN(30 * 24 * 3_600);
  const HALFDURATION1 = toBN(15 * 24 * 3_600);
  const OPENPERIOD1 = toBN(7 * 24 * 3_600);
  const HALFOPENPERIOD1 = toBN(7 * 12 * 3_600);

  //const provider =

  // beforeEach(async() => {
  //   this.snapshotId = await takeSnapshot();
  // });

  afterEach('revert', async () => {
    await revertToSnapshot(this.snapshotId);
  });

  before('setup', async () => {
    WETH = await MockERC20.new('WETH', 'WETH', '100000000', { from: MINTER });
    DAI = await MockERC20.new('DAI', 'DAI', '100000000', { from: MINTER });
    TKNX = await MockERC20.new('TokenX', 'TKNX', '100000000000', { from: MINTER });

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

  describe('Lock traders if investor getting big loss', async () => {
    beforeEach(async() => {
      this.snapshotId = await takeSnapshot();
    });
    it('Should be possible to lock trading by agreement', async () => {})
    it('Should not be possible to any trade if agreement is locked', async () => {})
  });

  describe('Trading', async () => {

    beforeEach

    describe('Swap ERC20 token to ERC20 token', async () => {
      it('Should be possible to create new exchange', async () => {
        let agreementId = 0,
          tokenIn = WETH.address,
          tokenOut = DAI.address,
          amountIn,
          amountOutMin,
          deadline = 0;

        await trade.swapTokenToToken(
          tokenIn,
          tokenOut,
          amountIn,
          amountOutMin,
          deadline
        );
      })
      it('Should be possible to create 2 new exchanges', async () => {})
    });

    describe('Swap ETH to ERC20 token', async () => {
      it('Should be possible to create new exchange', async () => {
        let agreementId = 0,
          tokenOut = WETH_DAI[0],
          amountOut,
          amountInMax,
          deadline = 0;

        await trade.swapETHForToken(
          agreementId,
          tokenOut,
          amountOut,
          amountInMax,
          deadline
        );
      })
    });

    describe('Swap ERC20 token to ETH', async () => {
      it('Should be possible to create new exchange', async () => {
        let agreementId = 0,
          tokenIn,
          amountIn,
          amountOutMin,
          deadline = 0;

        await trade.swapTokenForETH(
          agreementId,
          tokenIn,
          amountIn,
          amountOutMin,
          deadline
        );
      })
    });
  })


  describe('Closing of the agreement', async () => {

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

      //let's have IVNESTOR1 and INVEESTOR2 commit to Agreement
      await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
      //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
      await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), {from: INVESTOR1});
      //now let's introduce 1 more investor
      await DAI.approve(mandateBook.address, toWei(10_000), {from: INVESTOR2});
      await mandateBook.commitToAgreement(toBN(0), toWei(5_000), {from: INVESTOR2});
      (await mandateBook.getAgreementCommittedCapital(toBN(0))).should.be.bignumber.eq(toWei(35_000));

      await timeTravelTo(OPENPERIOD1);
    })

    it('Should not be possible to close agreement before deadline', async () => {})
    it('Should not be possible to close agreement twice', async () => {})
    it('Should not be possible to close agreement any other person, then manager', async () => {})
    it('Should be possible to close agreement, if manager has no trades', async () => {})
    it('Should be possible to close agreement', async () => {

    })
  });

  describe('Uniswap', async () => {

    // beforeEach(async() => {
    //   this.snapshotId = await takeSnapshot();
    // });

    it('Should be possible create new pair', async () => {
      let result = await factory.createPair(...WETH_DAI);

      WETH_DAI;
      assert.equal(result.logs.length, 1);
      assert.equal(result.logs[0].event, 'PairCreated');
      assert.equal(result.logs[0].args[0], WETH_DAI[1]);
      assert.equal(result.logs[0].args[1], WETH_DAI[0]);
      assert.equal(result.logs[0].args[3].toString(), String(1));

      // await expectEvent(result, "PairCreated", {
      //   token0: WETH_DAI[1],
      //   token1: WETH_DAI[0],
      //   pair: result.logs[0].args[2],
      //   3: toBN(1)
      // })
      await expectRevert(factory.createPair(...WETH_DAI), "UniswapV2: PAIR_EXISTS")
    })

    it('Should be possible create new pair and make liquidity', async () => {
      let result = await factory.createPair(...WETH_DAI);

      console.log(result.logs[0].args.pair)

      assert.equal(result.logs[0].args.pair, String(1));

      // await expectEvent(result, "PairCreated", {
      //   token0: WETH_DAI[1],
      //   token1: WETH_DAI[0],
      //   pair: result.logs[0].args[2],
      //   3: toBN(1)
      // })
      await expectRevert(factory.createPair(...WETH_DAI), "UniswapV2: PAIR_EXISTS")
    })

    it.only('Should be possible get cumulative price', async () => {
      let {logs} = await factory.createPair(...WETH_DAI);
      let pairAddress = logs[0].args.pair;

      const pair = new Contract(pairAddress, JSON.stringify(UniswapV2Pair.abi), provider)
      let token0 = await pair.token0()
      let token1 = await pair.token1()

      await token0.transfer(pair.address, expandTo18Decimals(10))
      await token1.transfer(pair.address, expandTo18Decimals(1000))


      // await expectRevert(trade.getPrice(WETH.address, DAI.address), "V20ORACLE: currentCumulativePrices call")
      let result = await trade.getPrice(WETH.address, DAI.address);
      console.log(result)
      //assert.m(calculatedAmount.toString(), expectedAmount, "calculated result has no expected value");
    })

  })

  // DONE
  describe('Couters and getters', async () => {
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

    it('Should be possible to count profit', async () => {
      let agreementId = 0;

      let { amount, positive } = await trade.countProfit(agreementId);

      assert.equal(amount, 0, "calculated result has no expected value");
      assert.equal(positive, false, "calculated result has no expected value");
    })

    it('Should be possible to get pure profit', async () => {
      let amountAssetD = 1000000,
        priceAssetD = 250,
        priceAssetX = 320;

      const excludeFee = (amount) => {
        amount = toBN(amount)
        const fee = toBN(3), feeDecimal = toBN(1000);
        return amount - ((amount / feeDecimal) * fee);
      }

      let expectedProfit = excludeFee(toBN(priceAssetX) * toBN(amountAssetD) - toBN(priceAssetD) * toBN(amountAssetD));
      let profit = await trade.calcPureProfit(amountAssetD, priceAssetD, priceAssetX);

      assert.equal(profit.toString(), expectedProfit, "calculated result has no expected value");
    })

    it('Should be possible get calculated amount', async () => {
      let amountAssetD = 1000000,
        priceAssetD = 250,
        priceAssetX = 320;

      const excludeFee = (amount) => {
        amount = toBN(amount)
        const fee = toBN(3), feeDecimal = toBN(1000);
        return amount - ((amount / feeDecimal) * fee);
      }

      let expectedAmount = excludeFee(toBN(priceAssetX) * toBN(amountAssetD) / toBN(priceAssetD));
      let calculatedAmount = await trade.calcAmount(amountAssetD, priceAssetD, priceAssetX);

      assert.equal(calculatedAmount.toString(), expectedAmount, "calculated result has no expected value");
    })

    // TODO: skipped becouse it internal method
    it.skip('Should be possible get calculated amount', async () => {
      const fee = 3,
        feeDecimal = 1000;
      let amountAssetD = 1000;

      let expectedAmount = amountAssetD - ((amountAssetD / feeDecimal) * fee);
      let calculatedAmount = await trade._excludeFees(amountAssetD);

      assert.equal(calculatedAmount.toString(), expectedAmount, "calculated result has no expected value");
    })
  });
})