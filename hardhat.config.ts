import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  networks: {
    hardhat: {
      gasPrice: 30000000000
    }
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: "14c853e7-3fe7-4254-8863-81d85f79a253"
  }
  
};


export default config;
