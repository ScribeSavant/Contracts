import { ethers } from "hardhat";
import { config as dotConfig } from "dotenv";

dotConfig();

async function main() {
  const router = "0x10ed43c718714eb63d5aa57b78b54704e256024e";
  const feeWallets: never[] = [];
  const token = await ethers.deployContract("GROKI1", [router, feeWallets]);

  await token.waitForDeployment();

  console.log(`Groki deployed to ${token.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
