import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import HardhatContractSizer from '@solidstate/hardhat-contract-sizer';
//import HardhatAbiExporter from '@solidstate/hardhat-abi-exporter';

const config: HardhatUserConfig = {
    plugins: [hardhatToolboxMochaEthers, HardhatContractSizer],
    solidity: {
        compilers: [
        {
          version: "0.8.31",
          settings: {
            //viaIR: true,
            optimizer: {
              enabled: true,
              runs: 500,
            },
            evmVersion: "osaka"
          },
        }]
      },
      contractSizer: {
        runOnCompile: true,
        strict: true
      },
};

export default config;