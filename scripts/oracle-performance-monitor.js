// base-oracle-network/scripts/performance-monitor.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function monitorOraclePerformance() {
  console.log("Monitoring Base Oracle Network performance...");
  
  const oracleAddress = "0x...";
  const oracle = await ethers.getContractAt("OracleNetworkV2", oracleAddress);
  
  // Получение статистики ораклов
  const oracleStats = await oracle.getNetworkStats();
  console.log("Network stats:", oracleStats);
  
  // Получение информации о конкретных ораклах
  const activeOracles = await oracle.getActiveOracles();
  console.log("Active oracles:", activeOracles.length);
  
  // Мониторинг производительности
  const performanceData = [];
  
  for (let i = 0; i < Math.min(5, activeOracles.length); i++) {
    const oracleAddress = activeOracles[i];
    const oraclePerformance = await oracle.getOraclePerformance(oracleAddress);
    
    performanceData.push({
      oracleAddress: oracleAddress,
      uptime: oraclePerformance.uptime.toString(),
      accuracy: oraclePerformance.accuracy.toString(),
      responseTime: oraclePerformance.responseTime.toString(),
      totalReports: oraclePerformance.totalReports.toString(),
      successfulReports: oraclePerformance.successfulReports.toString()
    });
  }
  
  // Анализ производительности
  const avgUptime = performanceData.reduce((sum, oracle) => sum + parseInt(oracle.uptime), 0) / performanceData.length;
  const avgAccuracy = performanceData.reduce((sum, oracle) => sum + parseInt(oracle.accuracy), 0) / performanceData.length;
  
  // Создание отчета
  const performanceReport = {
    timestamp: new Date().toISOString(),
    oracleAddress: oracleAddress,
    networkStats: oracleStats,
    oraclePerformance: performanceData,
    averages: {
      avgUptime: avgUptime.toString(),
      avgAccuracy: avgAccuracy.toString()
    },
    performanceIssues: [],
    improvementSuggestions: []
  };
  
  // Проверка на проблемы
  performanceData.forEach(oracle => {
    if (parseInt(oracle.uptime) < 95) {
      performanceReport.performanceIssues.push(`${oracle.oracleAddress} uptime below threshold`);
    }
    if (parseInt(oracle.accuracy) < 90) {
      performanceReport.performanceIssues.push(`${oracle.oracleAddress} accuracy below threshold`);
    }
  });
  
  // Рекомендации по улучшению
  if (avgUptime < 98) {
    performanceReport.improvementSuggestions.push("Improve oracle uptime reliability");
  }
  
  if (avgAccuracy < 95) {
    performanceReport.improvementSuggestions.push("Enhance oracle accuracy mechanisms");
  }
  
  // Сохранение отчета
  fs.writeFileSync(`./performance/performance-monitor-${Date.now()}.json`, JSON.stringify(performanceReport, null, 2));
  
  console.log("Performance monitoring completed successfully!");
  console.log("Issues found:", performanceReport.performanceIssues.length);
}

monitorOraclePerformance()
  .catch(error => {
    console.error("Performance monitoring error:", error);
    process.exit(1);
  });
