// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OracleNetworkV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct OracleNode {
        address nodeAddress;
        uint256 stakeAmount;
        uint256 lastReportTime;
        bool isActive;
        uint256 reputationScore;
        uint256 totalReports;
        uint256 totalCorrectReports;
        uint256 lastRewardTime;
        uint256 cumulativeRewards;
        string nodeUrl;
        uint256 commissionRate; // Commission rate for reporting
    }

    struct DataFeed {
        string feedId;
        address oracleAddress;
        uint256 latestPrice;
        uint256 timestamp;
        uint256 confidence;
        bool isActive;
        uint256 volume;
        uint256 averageVolume;
        uint256 priceChange24h;
        uint256 lastUpdated;
    }

    struct PriceRequest {
        uint256 requestId;
        address requester;
        string assetPair;
        uint256 timestamp;
        bool completed;
        uint256 price;
        uint256 fee;
        uint256 resolvedTime;
    }

    struct AggregatedData {
        uint256 weightedAverage;
        uint256 medianPrice;
        uint256 confidence;
        uint256 timestamp;
        uint256 sourceCount;
    }

    struct ReputationScore {
        uint256 score;
        uint256 lastUpdate;
        uint256 reliability;
        uint256 accuracy;
    }

    struct NodePerformance {
        uint256 totalReports;
        uint256 correctReports;
        uint256 accuracyRate;
        uint256 uptime;
        uint256 avgResponseTime;
        uint256 totalRewards;
    }

    struct FeedConfig {
        uint256 minConfidence;
        uint256 maxDeviation;
        uint256 refreshInterval;
        uint256 maxAge;
        bool enabled;
    }

    mapping(address => OracleNode) public oracleNodes;
    mapping(string => DataFeed) public dataFeeds;
    mapping(uint256 => PriceRequest) public priceRequests;
    mapping(address => mapping(string => uint256)) public nodeFeedScores;
    mapping(string => FeedConfig) public feedConfigs;
    mapping(address => NodePerformance) public nodePerformances;
    mapping(address => ReputationScore) public nodeReputations;
    
    address[] public activeOracles;
    uint256 public minStakeAmount;
    uint256 public requestFee;
    uint256 public nextRequestId;
    uint256 public totalOracleRewards;
    uint256 public totalReports;
    uint256 public totalValueLocked;
    
    // Configuration
    uint256 public constant MAX_COMMISSION_RATE = 10000; // 100%
    uint256 public constant MAX_REPUTATION_SCORE = 1000;
    uint256 public constant MIN_REPUTATION_SCORE = 0;
    uint256 public constant DEFAULT_MIN_CONFIDENCE = 8000; // 80%
    uint256 public constant DEFAULT_MAX_DEVIATION = 1000; // 10%
    uint256 public constant DEFAULT_REFRESH_INTERVAL = 300; // 5 minutes
    uint256 public constant DEFAULT_MAX_AGE = 3600; // 1 hour
    
    // Events
    event OracleRegistered(
        address indexed node,
        uint256 stakeAmount,
        string nodeUrl,
        uint256 timestamp
    );
    
    event OracleUnregistered(address indexed node, uint256 timestamp);
    event PriceReported(
        string indexed assetPair,
        uint256 price,
        address indexed oracle,
        uint256 confidence,
        uint256 timestamp
    );
    
    event PriceRequested(
        uint256 indexed requestId,
        address indexed requester,
        string assetPair,
        uint256 timestamp
    );
    
    event PriceResolved(
        uint256 indexed requestId,
        uint256 price,
        uint256 timestamp
    );
    
    event OracleRewarded(
        address indexed oracle,
        uint256 amount,
        uint256 timestamp
    );
    
    event OracleNodeUpdated(
        address indexed node,
        uint256 stakeAmount,
        string nodeUrl,
        uint256 timestamp
    );
    
    event FeedConfigUpdated(
        string indexed feedId,
        uint256 minConfidence,
        uint256 maxDeviation,
        uint256 refreshInterval,
        uint256 maxAge
    );
    
    event ReputationScoreUpdated(
        address indexed node,
        uint256 oldScore,
        uint256 newScore,
        string reason
    );
    
    event PerformanceMetricsUpdated(
        address indexed node,
        uint256 totalReports,
        uint256 correctReports,
        uint256 accuracyRate
    );

    constructor(
        uint256 _minStakeAmount,
        uint256 _requestFee
    ) {
        minStakeAmount = _minStakeAmount;
        requestFee = _requestFee;
    }

    // Register oracle
    function registerOracle(
        string memory nodeUrl,
        uint256 stakeAmount,
        uint256 commissionRate
    ) external {
        require(stakeAmount >= minStakeAmount, "Insufficient stake amount");
        require(commissionRate <= MAX_COMMISSION_RATE, "Commission rate too high");
        require(oracleNodes[msg.sender].nodeAddress == address(0), "Already registered");
        
        oracleNodes[msg.sender] = OracleNode({
            nodeAddress: msg.sender,
            stakeAmount: stakeAmount,
            lastReportTime: block.timestamp,
            isActive: true,
            reputationScore: MAX_REPUTATION_SCORE,
            totalReports: 0,
            totalCorrectReports: 0,
            lastRewardTime: block.timestamp,
            cumulativeRewards: 0,
            nodeUrl: nodeUrl,
            commissionRate: commissionRate
        });
        
        activeOracles.push(msg.sender);
        totalValueLocked = totalValueLocked.add(stakeAmount);
        
        emit OracleRegistered(msg.sender, stakeAmount, nodeUrl, block.timestamp);
    }

    // Update oracle info
    function updateOracleInfo(
        string memory nodeUrl,
        uint256 newStakeAmount,
        uint256 newCommissionRate
    ) external {
        require(oracleNodes[msg.sender].nodeAddress != address(0), "Not registered");
        require(newCommissionRate <= MAX_COMMISSION_RATE, "Commission rate too high");
        
        OracleNode storage node = oracleNodes[msg.sender];
        node.nodeUrl = nodeUrl;
        node.stakeAmount = newStakeAmount;
        node.commissionRate = newCommissionRate;
        node.lastReportTime = block.timestamp;
        
        totalValueLocked = totalValueLocked.sub(node.stakeAmount).add(newStakeAmount);
        
        emit OracleNodeUpdated(msg.sender, newStakeAmount, nodeUrl, block.timestamp);
    }

    // Unregister oracle
    function unregisterOracle() external {
        require(oracleNodes[msg.sender].nodeAddress != address(0), "Not registered");
        
        OracleNode storage node = oracleNodes[msg.sender];
        require(node.isActive, "Node already inactive");
        
        // Remove from active oracles
        for (uint256 i = 0; i < activeOracles.length; i++) {
            if (activeOracles[i] == msg.sender) {
                activeOracles[i] = activeOracles[activeOracles.length - 1];
                activeOracles.pop();
                break;
            }
        }
        
        totalValueLocked = totalValueLocked.sub(node.stakeAmount);
        delete oracleNodes[msg.sender];
        
        emit OracleUnregistered(msg.sender, block.timestamp);
    }

    // Report price
    function reportPrice(
        string memory assetPair,
        uint256 price,
        uint256 confidence
    ) external {
        require(oracleNodes[msg.sender].nodeAddress != address(0), "Not registered oracle");
        require(oracleNodes[msg.sender].isActive, "Oracle not active");
        require(confidence <= 10000, "Confidence too high");
        require(price > 0, "Invalid price");
        
        OracleNode storage node = oracleNodes[msg.sender];
        node.lastReportTime = block.timestamp;
        node.totalReports = node.totalReports.add(1);
        
        // Update reputation
        updateNodeReputation(msg.sender, true);
        
        // Update data feed
        DataFeed storage feed = dataFeeds[assetPair];
        feed.feedId = assetPair;
        feed.oracleAddress = msg.sender;
        feed.latestPrice = price;
        feed.timestamp = block.timestamp;
        feed.confidence = confidence;
        feed.isActive = true;
        feed.lastUpdated = block.timestamp;
        
        // Update stats
        totalReports = totalReports.add(1);
        
        emit PriceReported(assetPair, price, msg.sender, confidence, block.timestamp);
    }

    // Request price
    function requestPrice(
        string memory assetPair
    ) external payable {
        require(msg.value >= requestFee, "Insufficient fee");
        
        uint256 requestId = nextRequestId++;
        priceRequests[requestId] = PriceRequest({
            requestId: requestId,
            requester: msg.sender,
            assetPair: assetPair,
            timestamp: block.timestamp,
            completed: false,
            price: 0,
            fee: requestFee,
            resolvedTime: 0
        });
        
        emit PriceRequested(requestId, msg.sender, assetPair, block.timestamp);
    }

    // Get aggregated price
    function getPriceAggregated(
        string memory assetPair,
        uint256 minConfidence
    ) external view returns (uint256, uint256, uint256) {
        DataFeed storage feed = dataFeeds[assetPair];
        
        // Check minimum confidence
        if (feed.confidence < minConfidence) {
            return (0, 0, 0); // Insufficient confidence
        }
        
        // Check age
        if (block.timestamp > feed.timestamp + feedConfigs[assetPair].maxAge) {
            return (0, 0, 0); // Expired data
        }
        
        return (feed.latestPrice, feed.confidence, feed.timestamp);
    }

    // Get data feed
    function getDataFeed(string memory assetPair) external view returns (DataFeed memory) {
        return dataFeeds[assetPair];
    }

    // Get oracle info
    function getOracleInfo(address node) external view returns (OracleNode memory) {
        return oracleNodes[node];
    }

    // Get active oracles
    function getActiveOracles() external view returns (address[] memory) {
        return activeOracles;
    }

    // Get oracle stats
    function getOracleStats(address node) external view returns (
        uint256 totalReports,
        uint256 correctReports,
        uint256 accuracyRate,
        uint256 reputationScore,
        uint256 totalRewards
    ) {
        OracleNode storage oracle = oracleNodes[node];
        return (
            oracle.totalReports,
            oracle.totalCorrectReports,
            oracle.totalReports > 0 ? oracle.totalCorrectReports.mul(10000).div(oracle.totalReports) : 0,
            oracle.reputationScore,
            oracle.cumulativeRewards
        );
    }

    // Update node reputation
    function updateNodeReputation(address node, bool isCorrect) internal {
        OracleNode storage oracle = oracleNodes[node];
        
        if (isCorrect) {
            oracle.totalCorrectReports = oracle.totalCorrectReports.add(1);
        }
        
        // Update reputation
        uint256 accuracy = oracle.totalCorrectReports.mul(10000).div(oracle.totalReports);
        uint256 newReputation = oracle.reputationScore;
        
        // Basic reputation formula
        if (isCorrect) {
            newReputation = newReputation.add(10);
        } else {
            newReputation = newReputation > 10 ? newReputation.sub(10) : 0;
        }
        
        // Cap reputation
        if (newReputation > MAX_REPUTATION_SCORE) {
            newReputation = MAX_REPUTATION_SCORE;
        }
        
        oracle.reputationScore = newReputation;
        
        emit ReputationScoreUpdated(node, oracle.reputationScore, newReputation, isCorrect ? "Correct report" : "Incorrect report");
    }

    // Get aggregated data
    function getAggregatedData(
        string memory assetPair,
        uint256 maxAge
    ) external view returns (AggregatedData memory) {
        DataFeed storage feed = dataFeeds[assetPair];
        
        // Simple aggregation
        AggregatedData memory aggregated = AggregatedData({
            weightedAverage: feed.latestPrice,
            medianPrice: feed.latestPrice,
            confidence: feed.confidence,
            timestamp: feed.timestamp,
            sourceCount: 1
        });
        
        return aggregated;
    }

    // Get feed config
    function getFeedConfig(string memory assetPair) external view returns (FeedConfig memory) {
        return feedConfigs[assetPair];
    }

    // Set feed config
    function setFeedConfig(
        string memory assetPair,
        uint256 minConfidence,
        uint256 maxDeviation,
        uint256 refreshInterval,
        uint256 maxAge
    ) external onlyOwner {
        require(minConfidence <= 10000, "Min confidence too high");
        require(maxDeviation <= 10000, "Max deviation too high");
        require(refreshInterval > 0, "Invalid refresh interval");
        require(maxAge > 0, "Invalid max age");
        
        feedConfigs[assetPair] = FeedConfig({
            minConfidence: minConfidence,
            maxDeviation: maxDeviation,
            refreshInterval: refreshInterval,
            maxAge: maxAge,
            enabled: true
        });
        
        emit FeedConfigUpdated(assetPair, minConfidence, maxDeviation, refreshInterval, maxAge);
    }

    // Get network stats
    function getNetworkStats() external view returns (
        uint256 totalOracles,
        uint256 totalReports,
        uint256 totalValueLocked,
        uint256 activeFeeds,
        uint256 totalRewards
    ) {
        return (
            activeOracles.length,
            totalReports,
            totalValueLocked,
            0, // activeFeeds
            totalOracleRewards
        );
    }

    // Get request info
    function getRequestInfo(uint256 requestId) external view returns (PriceRequest memory) {
        return priceRequests[requestId];
    }

    // Check if data is fresh
    function isDataFresh(string memory assetPair, uint256 maxAge) external view returns (bool) {
        DataFeed storage feed = dataFeeds[assetPair];
        return block.timestamp <= feed.timestamp + maxAge;
    }

    // Get node reputation
    function getNodeReputation(address node) external view returns (ReputationScore memory) {
        return nodeReputations[node];
    }

    // Get node performance
    function getNodePerformance(address node) external view returns (NodePerformance memory) {
        return nodePerformances[node];
    }

    // Get all feeds
    function getAllFeeds() external view returns (string[] memory, DataFeed[] memory) {
        // Implementation in future
        string[] memory feeds = new string[](0);
        DataFeed[] memory feedData = new DataFeed[](0);
        return (feeds, feedData);
    }

    // Get network summary
    function getNetworkSummary() external view returns (
        uint256 totalActiveOracles,
        uint256 totalStaked,
        uint256 avgReputation,
        uint256 totalReportsProcessed
    ) {
        uint256 totalReputation = 0;
        for (uint256 i = 0; i < activeOracles.length; i++) {
            totalReputation = totalReputation.add(oracleNodes[activeOracles[i]].reputationScore);
        }
        
        uint256 avgRep = activeOracles.length > 0 ? totalReputation.div(activeOracles.length) : 0;
        
        return (
            activeOracles.length,
            totalValueLocked,
            avgRep,
            totalReports
        );
    }

    // Set min stake amount
    function setMinStakeAmount(uint256 newAmount) external onlyOwner {
        minStakeAmount = newAmount;
    }

    // Set request fee
    function setRequestFee(uint256 newFee) external onlyOwner {
        requestFee = newFee;
    }

    // Get staking info
    function getStakingInfo(address node) external view returns (uint256) {
        return oracleNodes[node].stakeAmount;
    }

    // Get oracle commission
    function getOracleCommission(address node) external view returns (uint256) {
        return oracleNodes[node].commissionRate;
    }

    // Get user history
    function getOracleHistory(address node) external view returns (uint256[] memory) {
        // Implementation in future
        return new uint256[](0);
    }
}
