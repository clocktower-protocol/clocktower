import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import HardhatContractSizer from '@solidstate/hardhat-contract-sizer';

const config: HardhatUserConfig = {
    plugins: [hardhatToolboxMochaEthers, HardhatContractSizer],
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
        runOnCompile: true,
        strict: true
      },
};

export default config;