// base-oracle-network/test/oracle-network.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Base Oracle Network", function () {
  let oracleNetwork;
  let oracleToken;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    
    // Деплой токена
    const OracleToken = await ethers.getContractFactory("ERC20Token");
    oracleToken = await OracleToken.deploy("Oracle Token", "ORCL");
    await oracleToken.deployed();
    
    // Деплой Oracle Network
    const OracleNetwork = await ethers.getContractFactory("OracleNetworkV2");
    oracleNetwork = await OracleNetwork.deploy(
      ethers.utils.parseEther("100"), // 100 tokens minimum stake
      ethers.utils.parseEther("0.1")  // 0.1 ETH request fee
    );
    await oracleNetwork.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await oracleNetwork.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await oracleNetwork.minStakeAmount()).to.equal(ethers.utils.parseEther("100"));
      expect(await oracleNetwork.requestFee()).to.equal(ethers.utils.parseEther("0.1"));
    });
  });

  describe("Oracle Registration", function () {
    it("Should register an oracle", async function () {
      await expect(oracleNetwork.registerOracle(
        "https://oracle.example.com",
        ethers.utils.parseEther("1000"),
        1000 // 10% commission
      )).to.emit(oracleNetwork, "OracleRegistered");
    });
  });

  describe("Price Reporting", function () {
    beforeEach(async function () {
      await oracleNetwork.registerOracle(
        "https://oracle.example.com",
        ethers.utils.parseEther("1000"),
        1000 // 10% commission
      );
    });

    it("Should report a price", async function () {
      await expect(oracleNetwork.reportPrice(
        "BTC/USD",
        50000,
        9500 // 95% confidence
      )).to.emit(oracleNetwork, "PriceReported");
    });
  });
});
