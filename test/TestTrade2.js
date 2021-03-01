const truffleContract = require('@truffle/contract');

const { BN, toBN, toChecksumAddress } = web3.utils;
require("chai").use(require("chai-bn")(BN)).should();

const Trade = artifacts.require('./Trade');
const MockERC20 = artifacts.require('./MockERC20');
// const UniswapV2Router02 = artifacts.require('./UniswapV2Router02');
// const UniswapV2Factory = artifacts.require('./UniswapV2Factory');
// const UniswapV2Pair = artifacts.require('./UniswapV2Pair');

const UniswapV2FactoryJson = require("@uniswap/v2-core/build/UniswapV2Factory");
const UniswapV2Router02Json = require("@uniswap/v2-periphery/build/UniswapV2Router02");
const UniswapV2PairJson = require("@uniswap/v2-core/build/UniswapV2Pair");
//
const UniswapV2Factory = truffleContract(UniswapV2FactoryJson);
const UniswapV2Router02 = truffleContract(UniswapV2Router02Json);
const UniswapV2Pair = truffleContract(UniswapV2PairJson);

UniswapV2Factory.setProvider(web3._provider);
UniswapV2Router02.setProvider(web3._provider);
UniswapV2Pair.setProvider(web3._provider);

const _require = require("app-root-path").require;
const BlockchainCaller = _require("/utils/blockchain_caller");

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
const { assert } = require('chai');

function toWei(x) {
  return web3.utils.toWei(toBN(x) /*, "nano"*/);
}

// add liquidity for pair
async function addLiquidity(
    router, // Contract
    pair,
    wallet,  // Address
    token0, // Contract
    token1, // Contract
    token0Amount = 0,
    token1Amount = 0,
    from
) {
  if (typeof pair === "string") {
    throw new Error('Pair: contract should be the instance');
  }

  await token0.approve(router.address, token0Amount, {from});
  await token1.approve(router.address, token1Amount, {from});

  const deadline = (await web3.eth.getBlock('latest')).timestamp + 10000;

  await router.addLiquidity(
      token0.address,
      token1.address,
      token0Amount,
      token1Amount,
      '0',
      '0',
      wallet,
      deadline,
      { from }
  );
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

  let agreementId;

  beforeEach(async () => {
    WETH = await MockERC20.new('WETH', 'WETH', toWei(1_000_000_000), { from: MINTER });
    DAI = await MockERC20.new('DAI', 'DAI', toWei(1_000_000_000), { from: MINTER });
    TKNX = await MockERC20.new('TokenX', 'TKNX', toWei(1_000_000_000_000), { from: MINTER });

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

    let result = await factory.createPair(...WETH_DAI, {
      from: OWNER
    });

    let wethDaiPairAddress = result.logs[0].args.pair;

    const wethDaiPair = await UniswapV2Pair.at(wethDaiPairAddress);

    await addLiquidity(
      router,
      wethDaiPair,
      MINTER,  // object
      WETH,
      DAI,
      toWei(100_000),
      toWei(100_000),
      MINTER
    );

    result = await factory.createPair(...WETH_TKNX, {
      from: OWNER
    });

    let wethTknxPairAddress = result.logs[0].args.pair;

    const wethTknxPair = await UniswapV2Pair.at(wethTknxPairAddress);

    await addLiquidity(
        router,
        wethTknxPair,
        MINTER,
        WETH,
        TKNX,
        toWei(100_000),
        toWei(100_000),
        MINTER
    );

    result = await factory.createPair(...DAI_TKNX, {
      from: OWNER
    });

    let daiTknxPairAddress = result.logs[0].args.pair;

    const daiTknxPair = await UniswapV2Pair.at(wethTknxPairAddress);

    // await addLiquidity({
    //   router,
    //   wallet: MINTER,  // object
    //   overrides: 0,
    //   token0: DAI,
    //   token1: TKNX,
    //   token0Amount: toWei('1000000'),
    //   token1Amount: toWei('1000000'),
    // }, { from: MINTER });

    // 0) investors and manager get moneys
    await DAI.transfer(MANAGER1, toWei(500_000), {from:MINTER});
    await DAI.transfer(INVESTOR1, toWei(150_000), {from:MINTER});
    await DAI.transfer(INVESTOR2, toWei(200_000), {from:MINTER});

    trade = await Trade.new(factory.address, router.address, { from: OWNER });
    mandateBook = trade;

    // 1) create agreement
    const receipt = await mandateBook.createAgreement(
        DAI.address, /* USDT testnet for example TODO change for own mock */
        30, /* targetReturnRate */
        80, /* maxCollateralRateIfAvailable */
        toWei(100_000), /* collatAmount */
        OPENPERIOD1, /* open period */
        DURATION1,  /* duration   */
        { from: MANAGER1 }
    );

    const event = receipt.logs[0];
    agreementId = event.args[0].toString();

    await mandateBook.publishAgreement(agreementId, {
      from: MANAGER1
    });
  });

  it ('Should not be able to swap tokens before activation of agreement', async () => {
    let tokenIn = WETH.address,
        tokenOut = DAI.address,
        amountIn = 1,
        amountOutMin = 380,
        deadline = 0;

    await expectRevert(trade.swapTokenToToken(
        agreementId,
        tokenIn,
        tokenOut,
        amountIn,
        amountOutMin,
        deadline, {
          from: MANAGER1
        }
    ), 'Reason given: Agreement status is not active');
  });

  it('Should not be possible to create new exchange not by manager', async () => {
    // 2) agreement going to the end
    //let's have IVNESTOR1 commit to Agreement
    await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
    //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
    await mandateBook.commitToAgreement(toBN(0), toWei(1_200_000), toBN(0), {from: INVESTOR1});

    await mandateBook.activateAgreement(agreementId, {
      from: MANAGER1
    });

    await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE

    let tokenIn = WETH.address,
        tokenOut = DAI.address,
        amountIn = 1,
        amountOutMin = 380,
        deadline = 0;

    await expectRevert(trade.swapTokenToToken(
        agreementId,
        tokenIn,
        tokenOut,
        amountIn,
        amountOutMin,
        deadline
    ), 'Caller is not agreement manager');
  });

  it('Should be possible to create new exchange', async () => {
    // 2) agreement going to the end
    //let's have IVNESTOR1 commit to Agreement
    await DAI.approve(mandateBook.address, toWei(30_000), {from: INVESTOR1});
    //let's make a commitment with the capital exceeding allowance, where expected is our algorithm will max at the allowance
    await mandateBook.commitToAgreement(agreementId, toWei(1_200_000), toBN(0), {from: INVESTOR1});

    await mandateBook.activateAgreement(agreementId, {
      from: MANAGER1
    });

    await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE

    let tokenIn = DAI.address,
        tokenOut = WETH.address,
        amountIn = toBN(1000),
        amountOutMin = toBN(1),
        deadline = (await web3.eth.getBlock('latest')).timestamp + 10000;

    agreementTradingDAIAmountBefore = await trade.agreementTradingTokenAmount(agreementId, tokenIn);
    agreementTradingWETHAmountBefore = await trade.agreementTradingTokenAmount(agreementId, tokenOut);
    assert.strictEqual(
      (await DAI.balanceOf(trade.address)).toString(10),
      agreementTradingDAIAmountBefore.toString(10)
    );
    assert.strictEqual(
      (await WETH.balanceOf(trade.address)).toString(10),
      agreementTradingWETHAmountBefore.toString(10)
    );

    const receipt = await trade.swapTokenToToken(
        agreementId,
        tokenIn,
        tokenOut,
        amountIn,
        amountOutMin,
        deadline,
        {
          from: MANAGER1
        }
    );

    amountInFromEvent = receipt.logs[0].args.amountIn.toString(10);
    amountOutFromEvent = receipt.logs[0].args.amountOut.toString(10);
    agreementTradingDAIAmount = await trade.agreementTradingTokenAmount(agreementId, tokenIn);
    agreementTradingWETHAmount = await trade.agreementTradingTokenAmount(agreementId, tokenOut);

    assert.strictEqual(
      agreementTradingDAIAmount.toString(10),
      agreementTradingDAIAmountBefore.sub(toBN(amountInFromEvent)).toString(10)
    );
    assert.strictEqual(
      agreementTradingWETHAmount.toString(10),
      agreementTradingWETHAmountBefore.add(toBN(amountOutFromEvent)).toString(10)
    );

    assert.strictEqual(
      (await DAI.balanceOf(trade.address)).toString(10),
      agreementTradingDAIAmount.toString(10)
    );
    assert.strictEqual(
      (await WETH.balanceOf(trade.address)).toString(10),
      agreementTradingWETHAmount.toString(10)
    );

    await expectEvent(
        receipt,
        'Traded'
    );
  });

  it('Should not be possible to close agreement before deadline', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) - 1000); // status agreement still ACTIVE
    await expectRevert(trade.sellAll(agreementId), "Agreement still active");
  });

  it('Should not be possible to close agreement twice', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) + Number(DURATION1.toString()) + 1000);
    await trade.setExpiredAgreement(agreementId);
    await trade.sellAll(agreementId, { from: MANAGER1 });
    assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");
    await expectRevert(trade.sellAll(agreementId, { from: MANAGER1 }), "Agreement was closed");
  })

  it('Should be possible to close agreement by any other person, then manager 1', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) + Number(DURATION1.toString()) + 1000);
    await trade.setExpiredAgreement(agreementId);
    await trade.sellAll(agreementId, { from: MANAGER2 });
  })

  it('Should be possible to close agreement by any other person, then manager 2', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) + Number(DURATION1.toString()) + 1000);
    await trade.setExpiredAgreement(agreementId);
    await trade.sellAll(agreementId, { from: TOKENHOLDER1 });
  })

  it('Should be possible to close agreement, if manager has no trades', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) + Number(DURATION1.toString()) + 1000);
    await trade.setExpiredAgreement(agreementId);
    await trade.sellAll(agreementId, { from: MANAGER1 });

    assert.equal(
      String((await trade.balances(agreementId)).init),
      String((await trade.balances(agreementId)).counted),
      "After close balance not equal to initial"
    );
  })

  it('Should be possible to close agreement', async () => {
    await timeTravelTo(Number(OPENPERIOD1.toString()) + Number(DURATION1.toString()) + 1000);
    await trade.setExpiredAgreement(agreementId);
    await trade.sellAll(agreementId, { from: MANAGER1 });

    assert.equal((await trade.agreementClosed(agreementId)), true, "Agreement was NOT closed");
  })

  // if('Should be able to trade by manager', async () => {
  //   await trade.swapTokenToToken(
  //       uint256 agreementId,
  //       address tokenIn,
  //       address tokenOut,
  //       uint256 amountIn,
  //       uint256 amountOut,
  //       uint256 deadline
  //   );
  // });
})
