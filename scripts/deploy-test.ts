import { ethers } from "hardhat";
import { config as dotConfig } from "dotenv";

dotConfig();

async function main() {
  const router = "0x636f6407B90661b73b1C0F7e24F4C79f624d0738";
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
