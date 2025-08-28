// base-oracle-network/scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Base Oracle Network...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Деплой токена
  const OracleToken = await ethers.getContractFactory("ERC20Token");
  const oracleToken = await OracleToken.deploy("Oracle Token", "ORCL");
  await oracleToken.deployed();

  // Деплой Oracle Network контракта
  const OracleNetwork = await ethers.getContractFactory("OracleNetworkV2");
  const oracleNetwork = await OracleNetwork.deploy(
    ethers.utils.parseEther("100"), // 100 tokens minimum stake
    ethers.utils.parseEther("0.1")  // 0.1 ETH request fee
  );

  await oracleNetwork.deployed();

  console.log("Base Oracle Network deployed to:", oracleNetwork.address);
  console.log("Oracle Token deployed to:", oracleToken.address);
  
  // Сохраняем адреса
  const fs = require("fs");
  const data = {
    oracleNetwork: oracleNetwork.address,
    oracleToken: oracleToken.address,
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/deployment.json", JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
