import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-ledger";
import 'solidity-docgen'
require('dotenv').config();

const config: HardhatUserConfig = {
  
  solidity: {
    version: "0.8.26",
    settings: {
      //viaIR: true,
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  contractSizer: {
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true
  },
  networks: {
    hardhat: {
      ignition: {
        maxFeePerGasLimit: 50_000_000_000n, // 50 gwei
        maxPriorityFeePerGas: 3_000_000_000n, // 3 gwei
      },
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/REMOVED",
        blockNumber: 20584960,
        enabled: true
      },
      //gas: 50_000_000_000
     // gasPrice: 30000000000
    }, 
    /*
    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_URL,
      ledgerAccounts: [
        process.env.SEPOLIA_DEPLOYER_ADDRESS,
      ],
    }
    */
  },
  gasReporter: {
    enabled: true,
    L2: "base",
    //L1: "ethereum",
    currencyDisplayPrecision: 5,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    //gasPriceApi: process.env.ETHERSCAN_GAS_LOOKUP_URL,
    L2Etherscan: process.env.BASESCAN_KEY,
    L1Etherscan: process.env.ETHERSCAN_KEY
  },
  
};


export default config;
