import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";

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
    //L1Etherscan: "REMOVED",
    coinmarketcap: "14c853e7-3fe7-4254-8863-81d85f79a253",
    gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice&apikey=REMOVED"
  },
  
};


export default config;
