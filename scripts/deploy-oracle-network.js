const fs = require("fs");
const path = require("path");
require("dotenv").config();

function parseList(v) {
  return (v || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  let reporters = parseList(process.env.REPORTERS);
  if (reporters.length === 0) reporters = [deployer.address];

  const Oracle = await ethers.getContractFactory("OracleNetwork");
  const oracle = await Oracle.deploy(reporters);
  await oracle.deployed();

  console.log("OracleNetwork:", oracle.address);

  
  let dataFeedAddr = "";
  const uses = process.env.DATAFEED_USES_ORACLE === "1";
  if (uses) {
    const DataFeed = await ethers.getContractFactory("DataFeed");
    const df = await DataFeed.deploy(oracle.address);
    await df.deployed();
    dataFeedAddr = df.address;
    console.log("DataFeed:", dataFeedAddr);
  }

  const out = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    contracts: {
      OracleNetwork: oracle.address,
      DataFeed: dataFeedAddr || null
    },
    params: { reporters }
  };

  const outPath = path.join(__dirname, "..", "deployments.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
