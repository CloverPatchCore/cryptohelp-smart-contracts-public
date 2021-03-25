/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

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
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

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

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.6",    // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "istanbul"
      }
    },
  },
  plugins: ["solidity-coverage", "truffle-plugin-verify"],
  api_keys: { etherscan: ETHERSCAN_KEY, bscscan: BSCSCAN_KEY }
};
