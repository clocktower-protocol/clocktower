import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-ledger";
import 'solidity-docgen'
require('dotenv').config();

const config: HardhatUserConfig = {
  
  solidity: {
    compilers: [
    {
      version: "0.8.28",
      settings: {
        //viaIR: true,
        optimizer: {
          enabled: true,
          runs: 500,
        },
        evmVersion: "cancun"
      },
    }]
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
        url: process.env.FORK_DATA_SOURCE,
        blockNumber: 20584960,
        enabled: false
      },
      //gas: 50_000_000_000
     // gasPrice: 30000000000
    }, 
    /*
    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_URL,
      chainId: 11155111
      ledgerAccounts: [
        process.env.SEPOLIA_DEPLOYER_ADDRESS,
      ],
    },
    sepoliaBase: {
      url: process.env.ALCHEMY_SEPOLIA_BASE_URL,
      chainId: 84532
      ledgerAccounts: [
        process.env.SEPOLIA_BASE_DEPLOYER_ADDRESS,
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
