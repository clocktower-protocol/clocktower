import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import HardhatContractSizer from '@solidstate/hardhat-contract-sizer';
import HardhatAbiExporter from '@solidstate/hardhat-abi-exporter';

const config: HardhatUserConfig = {
    plugins: [hardhatToolboxMochaEthers, HardhatContractSizer, HardhatAbiExporter],
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
      abiExporter: {
        runOnCompile: true,
        clear: true
      }
};

export default config;