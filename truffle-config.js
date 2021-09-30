const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config()

const {
  MNEMONIC_PHRASE,
  INFURA_KEY,
  ETHERSCAN_KEY,
  BSCSCAN_KEY,
  GAS_PRICE
} = process.env;

const gasPrice = Number(GAS_PRICE) * 10 ** 9;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      network_id: "*",
      port: 8545,
      confirmations: 0,
      skipDryRun: true,
      gasPrice,
    },
    rinkeby: {
      provider: () => new HDWalletProvider(MNEMONIC_PHRASE, `https://rinkeby.infura.io/v3/${INFURA_KEY}`),
      network_id: 4,
      confirmations: 1,
      skipDryRun: true,
      gasPrice,
    },
    mainnet: {
      provider: () => new HDWalletProvider(MNEMONIC_PHRASE, `https://mainnet.infura.io/v3/${INFURA_KEY}`),
      network_id: 1,
      confirmations: 3,
      skipDryRun: true,
      gasPrice
    },
    bscTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC_PHRASE, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 1,
      skipDryRun: true,
      gasPrice
    },
    bscMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC_PHRASE, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 3,
      skipDryRun: true,
      gasPrice
    }
  },
  compilers: {
    solc: {
      version: "0.6.6",
      docker: false,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "istanbul"
      }
    },
  },
  plugins: ["solidity-coverage", "truffle-plugin-verify"],
  api_keys: { etherscan: ETHERSCAN_KEY, bscscan: BSCSCAN_KEY },
  mocha: { reporter: 'eth-gas-reporter', reporterOptions: { currency: "USD" } }
};
