import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";

const config: HardhatUserConfig = {
  
  networks: {
    hardhat: {
      gasPrice: 20000000000
    }
  },
  solidity: "0.8.17",
  
};


export default config;
