const { ChainId, WETH, Token, TokenAmount, Pair, Route } = require('@uniswap/sdk');

const chainId = ChainId.MAINNET;

console.log(`The chainId of mainnet is ${chainId}.`);

const token = new Token(chainId, '0xc0FFee0000000000000000000000000000000000', 18, 'HOT', 'Caffeine');

console.log(token);

const HOT = new Token(chainId, '0xc0FFee0000000000000000000000000000000000', 18, 'HOT', 'Caffeine');
const NOT = new Token(chainId, '0xDeCAf00000000000000000000000000000000000', 18, 'NOT', 'Caffeine');

const HOT_NOT = new Pair(new TokenAmount(HOT, '2000000000000000000'), new TokenAmount(NOT, '1000000000000000000'));

console.log(HOT_NOT);

const route = new Route([HOT_NOT], NOT);

console.log(route);