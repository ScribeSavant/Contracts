import { ethers } from "hardhat";
import { config as dotConfig } from "dotenv";

dotConfig();

async function main() {
  const [owner, second] = await ethers.getSigners();

  const grok = await ethers.getContractAt(
    "GROK",
    "0xF10CD9268F3DCEebdfA572896683f72268c65FF4"
  );
  const router = await ethers.getContractAt(
    "IPulseXRouter02",
    "0x636f6407B90661b73b1C0F7e24F4C79f624d0738"
  );
  var deadline = new Date(
    Date.parse(new Date() as unknown as string) + 15 * 24 * 60 * 60 * 1000
  );
  while (true) {
    const tx = await router
      .connect(second)
      .swapExactETHForTokensSupportingFeeOnTransferTokens(
        0n,
        [await router.WPLS(), grok.target],
        second,
        deadline.valueOf(),
        {
          value: ethers.parseEther("1"),
        }
      )
      .catch((err) => {
        console.log("Err while buy", err.message);
      });
    if (tx) {
      console.log(tx);
      break;
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
