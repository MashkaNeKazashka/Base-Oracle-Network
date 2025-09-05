// base-oracle-network/scripts/monitor.js
const { ethers } = require("hardhat");

async function monitorOracleNetwork() {
  console.log("Monitoring Base Oracle Network...");
  
  const oracleAddress = "0x...";
  const oracle = await ethers.getContractAt("OracleNetworkV2", oracleAddress);
  
  // Получение статистики ораклов
  const oracleStats = await oracle.getNetworkStats();
  console.log("Oracle Network Stats:", {
    totalOracles: oracleStats.totalOracles.toString(),
    totalReports: oracleStats.totalReports.toString(),
    totalValueLocked: oracleStats.totalValueLocked.toString(),
    activeFeeds: oracleStats.activeFeeds.toString(),
    totalRewards: oracleStats.totalRewards.toString()
  });
  
  // Получение информации о конкретных ораклах
  const activeOracles = await oracle.getActiveOracles();
  console.log("Active Oracles:", activeOracles);
  
  // Мониторинг отчетов
  oracle.on("PriceReported", (assetPair, price, oracleAddress, confidence, timestamp) => {
    console.log(`Price reported: ${assetPair} = ${price} with confidence ${confidence}%`);
  });
  
  // Мониторинг наград
  oracle.on("OracleRewarded", (oracleAddress, amount, timestamp) => {
    console.log(`Oracle rewarded: ${oracleAddress} received ${amount}`);
  });
  
  console.log("Oracle monitoring started. Press Ctrl+C to stop.");
  
  // Запуск мониторинга на 5 минут
  setTimeout(() => {
    console.log("Monitoring stopped.");
    process.exit(0);
  }, 300000); // 5 минут
}

monitorOracleNetwork()
  .catch(error => {
    console.error("Monitoring error:", error);
    process.exit(1);
  });
