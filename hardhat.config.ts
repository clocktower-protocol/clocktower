import type { HardhatUserConfig } from "hardhat/config";

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
};

export default config;