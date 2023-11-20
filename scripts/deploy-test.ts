import { ethers } from "hardhat";
import { config as dotConfig } from "dotenv";

dotConfig();

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();
  const router = "0xDE2Db97D54a3c3B008a097B2260633E6cA7DB1AF";
  const feeWallets = [
    otherAccount.address,
    otherAccount.address,
    otherAccount.address,
  ];
  const token = await ethers.deployContract("TOKEN", [router, feeWallets]);

  await token.waitForDeployment();

  console.log(`TOKEN deployed to ${token.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
