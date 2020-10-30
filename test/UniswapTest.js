require('dotenv').config()

const { ChainId, Fetcher, WETH, Token, TokenAmount, Pair, Route, Trade, TradeType, Percent } = require('@uniswap/sdk');
const ethers = require('ethers');

const { getAddress } = ethers.utils;

const UniswapV2Router02 = require('../build/contracts/UniswapV2Router02.json');

const chainId = ChainId.MAINNET;

const {
  MNEMONIC_PHRASE,
  INFURA_KEY,
  PRIVATE_KEY
} = process.env;

const init = async () => {
  console.log(`The chainId is ${chainId}.`);

  const daiMainnetAddress = getAddress('0x6b175474e89094c44da98b954eedeac495271d0f');
  const dai = await Fetcher.fetchTokenData(chainId, daiMainnetAddress)
  const weth = WETH[chainId]
  const pair = await Fetcher.fetchPairData(dai, weth)

  const routePairWeth = new Route([pair], weth)
  const trade = new Trade(routePairWeth, new TokenAmount(weth, '100000000000000000'), TradeType.EXACT_INPUT)

  console.log(routePairWeth.midPrice.toSignificant(6))
  console.log(routePairWeth.midPrice.invert().toSignificant(6))
  console.log(trade.executionPrice.toSignificant(6))
  console.log(trade.nextMidPrice.toSignificant(6))

  // const token = new Token(chainId, '0xc0FFee0000000000000000000000000000000000', 18, 'HOT', 'Caffeine');
  //
  // console.log(token);
  //
  // const HOT = new Token(chainId, '0xc0FFee0000000000000000000000000000000000', 18, 'HOT', 'Caffeine');
  // const NOT = new Token(chainId, '0xDeCAf00000000000000000000000000000000000', 18, 'NOT', 'Caffeine');

  // const HOT_NOT = new Pair(new TokenAmount(HOT, '2000000000000000000'), new TokenAmount(NOT, '1000000000000000000'));
  //
  // console.log(HOT_NOT);

  // const route = new Route([HOT_NOT], NOT);
  //
  // console.log(route);
  //
  // const provider = ethers.getDefaultProvider('mainnet', {
  //   infura: `https://mainnet.infura.io/v3/${INFURA_KEY}`
  // });
  //
  // const signer = new ethers.Wallet(PRIVATE_KEY);
  // const account = signer.connect(provider);
  // const uniswap = new ethers.Contract(
  //   '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
  //   JSON.stringify(UniswapV2Router02.abi),
  //   account
  // );
}

init();