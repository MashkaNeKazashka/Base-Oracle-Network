require("dotenv").config();
const fs = require("fs"); 
const path = require("path");

async function main() {
  const depPath = path.join(__dirname, "..", "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(depPath, "utf8"));

  const oracleAddr = deployments.contracts.OracleNetwork;
  const [r1, r2, r3] = await ethers.getSigners();

  const oracle = await ethers.getContractAt("OracleNetwork", oracleAddr);
  console.log("Oracle:", oracleAddr);

  const assetId = ethers.utils.id("ETH/USD");
  await (await oracle.connect(r1).report(assetId, 3000)).wait();
  await (await oracle.connect(r2).report(assetId, 3100)).wait();
  await (await oracle.connect(r3).report(assetId, 3050)).wait();

  const median = await oracle.getMedian(assetId);
  console.log("Median:", median.toString());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

