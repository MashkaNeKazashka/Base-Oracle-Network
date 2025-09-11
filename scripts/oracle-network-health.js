// base-oracle-network/scripts/health.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function healthCheckOracleNetwork() {
  console.log("Performing health check for Base Oracle Network...");
  
  const oracleAddress = "0x...";
  const oracle = await ethers.getContractAt("OracleNetworkV2", oracleAddress);
  
  // Проверка здоровья сети
  const healthReport = {
    timestamp: new Date().toISOString(),
    oracleAddress: oracleAddress,
    networkStatus: {},
    oracleMetrics: {},
    dataQuality: {},
    performance: {},
    alerts: [],
    recommendations: []
  };
  
  try {
    // Статус сети
    const networkStatus = await oracle.getNetworkStatus();
    healthReport.networkStatus = {
      totalOracles: networkStatus.totalOracles.toString(),
      activeOracles: networkStatus.activeOracles.toString(),
      uptime: networkStatus.uptime.toString(),
      lastHeartbeat: networkStatus.lastHeartbeat.toString(),
      networkStatus: networkStatus.networkStatus
    };
    
    // Метрики ораклов
    const oracleMetrics = await oracle.getOracleMetrics();
    healthReport.oracleMetrics = {
      avgAccuracy: oracleMetrics.avgAccuracy.toString(),
      avgResponseTime: oracleMetrics.avgResponseTime.toString(),
      totalReports: oracleMetrics.totalReports.toString(),
      successRate: oracleMetrics.successRate.toString(),
      avgConfidence: oracleMetrics.avgConfidence.toString()
    };
    
    // Качество данных
    const dataQuality = await oracle.getDataQuality();
    healthReport.dataQuality = {
      dataFreshness: dataQuality.dataFreshness.toString(),
      consistency: dataQuality.consistency.toString(),
      availability: dataQuality.availability.toString(),
      accuracy: dataQuality.accuracy.toString(),
      integrity: dataQuality.integrity.toString()
    };
    
    // Производительность
    const performance = await oracle.getPerformance();
    healthReport.performance = {
      avgProcessingTime: performance.avgProcessingTime.toString(),
      maxProcessingTime: performance.maxProcessingTime.toString(),
      throughput: performance.throughput.toString(),
      errorRate: performance.errorRate.toString(),
      latency: performance.latency.toString()
    };
    
    // Проверка на проблемы
    if (parseFloat(healthReport.oracleMetrics.successRate) < 90) {
      healthReport.alerts.push("Low oracle success rate detected");
    }
    
    if (parseFloat(healthReport.performance.errorRate) > 5) {
      healthReport.alerts.push("High error rate in oracle network");
    }
    
    if (parseFloat(healthReport.dataQuality.accuracy) < 95) {
      healthReport.alerts.push("Low data accuracy detected");
    }
    
    // Рекомендации
    if (parseFloat(healthReport.oracleMetrics.successRate) < 95) {
      healthReport.recommendations.push("Investigate oracle reliability issues");
    }
    
    if (parseFloat(healthReport.performance.errorRate) > 2) {
      healthReport.recommendations.push("Optimize oracle processing performance");
    }
    
    if (parseFloat(healthReport.dataQuality.accuracy) < 98) {
      healthReport.recommendations.push("Implement data quality improvements");
    }
    
    // Сохранение отчета
    const healthFileName = `oracle-health-${Date.now()}.json`;
    fs.writeFileSync(`./health/${healthFileName}`, JSON.stringify(healthReport, null, 2));
    console.log(`Health report created: ${healthFileName}`);
    
    console.log("Oracle network health check completed successfully!");
    console.log("Alerts:", healthReport.alerts.length);
    console.log("Recommendations:", healthReport.recommendations);
    
  } catch (error) {
    console.error("Health check error:", error);
    throw error;
  }
}

healthCheckOracleNetwork()
  .catch(error => {
    console.error("Health check failed:", error);
    process.exit(1);
  });
