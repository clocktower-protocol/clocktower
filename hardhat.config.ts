import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
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
    runOnCompile: true,
    strict: true
  },
  networks: {
    hardhat: {
      gasPrice: 30000000000
    }
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
