import { ethers } from "hardhat";
import { config as dotConfig } from "dotenv";

dotConfig();

async function main() {
  const router = "0x165C3410fC91EF562C50559f7d2289fEbed552d9";
  const feeWallet = process.env.FEE_WALLET;
  const grok = await ethers.deployContract("GROK", [router, feeWallet]);

  await grok.waitForDeployment();

  console.log(`GROK deployed to ${grok.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
