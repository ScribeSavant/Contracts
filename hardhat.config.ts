import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";

import { config as dotConfig } from "dotenv";

dotConfig();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    tbsc: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      accounts: process.env.TESTNET_PRIVATE_KEYS?.split(",").filter(
        (pv) => pv != undefined
      ),
    },
    bsc: {
      url: "https://bsc-dataseed1.binance.org/",
      chainId: 56,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
  },
  etherscan: {
    apiKey: "KV825EWSIR3KUXT1J16D1I9E99SII7REG9",
  },
};

export default config;
