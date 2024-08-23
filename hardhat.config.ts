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
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  contractSizer: {
    disambiguatePaths: false,
    runOnCompile: false,
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
    //L2: "optimism",
    L1: "ethereum",
    currencyDisplayPrecision: 5,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    gasPriceApi: process.env.ETHERSCAN_GAS_LOOKUP_URL
  },
  
};


export default config;
