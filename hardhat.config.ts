import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";

const config: HardhatUserConfig = {
    plugins: [hardhatToolboxMochaEthers],
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
};

export default config;