import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import { config as dotConfig } from "dotenv";

dotConfig();

const config: HardhatUserConfig = {
  solidity: "0.8.0",
  networks: {
    tpls: {
      url: "https://rpc.v4.testnet.pulsechain.com/",
      chainId: 943,
      accounts: process.env.TESTNET_PRIVATE_KEYS?.split(","),
    },
    pls: {
      url: "https://rpc.pulsechain.com",
      chainId: 369,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      tpls: "0",
      pls: "0",
    },
    customChains: [
      {
        network: "tpls",
        chainId: 943,
        urls: {
          apiURL: "https://scan.v4.testnet.pulsechain.com/api",
          browserURL: "https://scan.v4.testnet.pulsechain.com",
        },
      },
      {
        network: "pls",
        chainId: 369,
        urls: {
          apiURL: "https://scan.pulsechain.com/api",
          browserURL: "https://scan.pulsechain.com/",
        },
      },
    ],
  },
};

export default config;
