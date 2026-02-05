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
        
    
        updateNodeReputation(msg.sender, true);
        

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
    // Добавить функции:
function reportCrossChainData(
    uint256 sourceChainId,
    string memory data,
    uint256 timestamp
) external {
    // Отчет о данных с другой цепочки
}

function verifyCrossChainData(
    uint256 sourceChainId,
    bytes32 dataHash,
    bytes32[] memory signatures
) external view returns (bool) {
    // Верификация данных с другой цепочки
}
// Добавить структуры:
struct CrossChainVerification {
    uint256 chainId;
    bytes32 dataHash;
    uint256 timestamp;
    uint256 verificationCount;
    address[] verifiers;
    bool verified;
    uint256 confidenceScore;
}

struct DataVerification {
    bytes32 dataHash;
    uint256 timestamp;
    address[] reporters;
    uint256 reporterCount;
    uint256 verificationThreshold;
    bool confirmed;
    uint256 confidence;
    string sourceChain;
}

// Добавить маппинги:
mapping(bytes32 => CrossChainVerification) public crossChainVerifications;
mapping(bytes32 => DataVerification) public dataVerifications;

// Добавить события:
event DataVerified(
    bytes32 indexed dataHash,
    uint256 chainId,
    uint256 confidence,
    uint256 timestamp
);

event CrossChainVerificationRequested(
    bytes32 indexed dataHash,
    uint256 chainId,
    uint256 timestamp
);

event VerificationConfirmed(
    bytes32 indexed dataHash,
    uint256 verificationCount,
    uint256 confidence,
    bool success
);

// Добавить функции:
function requestCrossChainVerification(
    bytes32 dataHash,
    uint256 chainId,
    string memory sourceChain
) external {
    require(chainId != 0, "Invalid chain ID");
    
    CrossChainVerification storage verification = crossChainVerifications[dataHash];
    verification.chainId = chainId;
    verification.dataHash = dataHash;
    verification.timestamp = block.timestamp;
    verification.verificationCount = 0;
    verification.verified = false;
    verification.confidenceScore = 0;
    
    // Add to verifiers array
    verification.verifiers.push(msg.sender);
    
    emit CrossChainVerificationRequested(dataHash, chainId, block.timestamp);
}

function verifyDataCrossChain(
    bytes32 dataHash,
    uint256 chainId,
    uint256 confidence,
    bytes32[] memory signatures
) external {
    CrossChainVerification storage verification = crossChainVerifications[dataHash];
    require(verification.chainId == chainId, "Chain ID mismatch");
    require(verification.dataHash == dataHash, "Data hash mismatch");
    require(!verification.verified, "Already verified");
    
    // Verify signatures (simplified)
    verification.verificationCount++;
    verification.confidenceScore = (verification.confidenceScore + confidence) / 2;
    verification.verifiers.push(msg.sender);
    
    // Check if verification threshold reached
    if (verification.verificationCount >= 3) { // Simplified threshold
        verification.verified = true;
        emit DataVerified(dataHash, chainId, confidence, block.timestamp);
    }
    
    emit VerificationConfirmed(dataHash, verification.verificationCount, confidence, verification.verified);
}

function confirmDataVerification(
    bytes32 dataHash,
    uint256 confidence,
    string memory sourceChain
) external {
    DataVerification storage verification = dataVerifications[dataHash];
    verification.dataHash = dataHash;
    verification.timestamp = block.timestamp;
    verification.reporters.push(msg.sender);
    verification.reporterCount++;
    verification.verificationThreshold = 3; // Simplified
    verification.confirmed = false;
    verification.confidence = confidence;
    verification.sourceChain = sourceChain;
    
    // Check if enough confirmations
    if (verification.reporterCount >= verification.verificationThreshold) {
        verification.confirmed = true;
        emit VerificationConfirmed(dataHash, verification.reporterCount, confidence, true);
    }
}

function getCrossChainVerification(bytes32 dataHash) external view returns (CrossChainVerification memory) {
    return crossChainVerifications[dataHash];
}

function getDataVerification(bytes32 dataHash) external view returns (DataVerification memory) {
    return dataVerifications[dataHash];
}

function getVerificationStats() external view returns (
    uint256 totalVerifications,
    uint256 confirmedVerifications,
    uint256 pendingVerifications,
    uint256 averageConfidence
) {
    // Implementation would return verification statistics
    return (0, 0, 0, 0);
}

function verifyDataWithSignature(
    bytes32 dataHash,
    bytes32 signature,
    address signer
) external view returns (bool) {
    // Simplified signature verification
    return true;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OracleNetwork is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Существующие структуры и функции...
    
    // Новые структуры для кросс-цепочечных оракулов
    struct CrossChainOracle {
        uint256 chainId;
        address oracleAddress;
        string chainName;
        uint256 reliabilityScore;
        uint256 lastReportTime;
        uint256 totalReports;
        uint256 correctReports;
        bool active;
        uint256 fee;
        uint256 maxDeviation;
        uint256 confidenceThreshold;
    }
    
    struct CrossChainData {
        bytes32 dataHash;
        address[] reporters;
        uint256[] confidenceScores;
        uint256[] timestamps;
        uint256[] chainIds;
        string assetPair;
        uint256 price;
        uint256 timestamp;
        bool verified;
        uint256 finalConfidence;
        mapping(uint256 => bool) verifiedByChain;
    }
    
    struct ChainConfig {
        uint256 chainId;
        string chainName;
        address bridgeContract;
        uint256 fee;
        uint256 maxDeviation;
        uint256 confidenceThreshold;
        bool enabled;
        uint256 lastUpdated;
    }
    
    struct AggregatedDataPoint {
        string assetPair;
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 sourceCount;
        uint256[] sourceChainIds;
        uint256[] sourcePrices;
        uint256[] sourceConfidences;
    }
    
    // Новые маппинги
    mapping(uint256 => CrossChainOracle) public crossChainOracles;
    mapping(bytes32 => CrossChainData) public crossChainData;
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(string => AggregatedDataPoint) public aggregatedData;
    mapping(uint256 => mapping(uint256 => bool)) public oracleChainPermissions;
    
    // Новые события
    event CrossChainOracleRegistered(
        uint256 indexed chainId,
        address indexed oracleAddress,
        string chainName,
        uint256 fee,
        uint256 timestamp
    );
    
    event CrossChainDataReported(
        bytes32 indexed dataHash,
        uint256 indexed chainId,
        string assetPair,
        uint256 price,
        uint256 confidence,
        uint256 timestamp
    );
    
    event CrossChainDataVerified(
        bytes32 indexed dataHash,
        uint256 chainId,
        uint256 finalConfidence,
        bool success,
        uint256 timestamp
    );
    
    event ChainConfigUpdated(
        uint256 indexed chainId,
        string chainName,
        uint256 fee,
        uint256 maxDeviation,
        uint256 confidenceThreshold,
        bool enabled
    );
    
    event DataAggregated(
        string indexed assetPair,
        uint256 aggregatedPrice,
        uint256 confidence,
        uint256 timestamp
    );
    
    // Новые функции для кросс-цепочечных оракулов
    function registerCrossChainOracle(
        uint256 chainId,
        address oracleAddress,
        string memory chainName,
        uint256 fee,
        uint256 maxDeviation,
        uint256 confidenceThreshold
    ) external onlyOwner {
        require(chainId > 0, "Invalid chain ID");
        require(oracleAddress != address(0), "Invalid oracle address");
        require(bytes(chainName).length > 0, "Chain name cannot be empty");
        require(fee <= 10000, "Fee too high");
        require(maxDeviation <= 10000, "Max deviation too high");
        require(confidenceThreshold <= 10000, "Confidence threshold too high");
        
        crossChainOracles[chainId] = CrossChainOracle({
            chainId: chainId,
            oracleAddress: oracleAddress,
            chainName: chainName,
            reliabilityScore: 10000, // 100%
            lastReportTime: block.timestamp,
            totalReports: 0,
            correctReports: 0,
            active: true,
            fee: fee,
            maxDeviation: maxDeviation,
            confidenceThreshold: confidenceThreshold
        });
        
        emit CrossChainOracleRegistered(chainId, oracleAddress, chainName, fee, block.timestamp);
    }
    
    function updateChainConfig(
        uint256 chainId,
        string memory chainName,
        uint256 fee,
        uint256 maxDeviation,
        uint256 confidenceThreshold,
        bool enabled
    ) external onlyOwner {
        require(chainId > 0, "Invalid chain ID");
        require(bytes(chainName).length > 0, "Chain name cannot be empty");
        require(fee <= 10000, "Fee too high");
        require(maxDeviation <= 10000, "Max deviation too high");
        require(confidenceThreshold <= 10000, "Confidence threshold too high");
        
        chainConfigs[chainId] = ChainConfig({
            chainId: chainId,
            chainName: chainName,
            bridgeContract: address(0),
            fee: fee,
            maxDeviation: maxDeviation,
            confidenceThreshold: confidenceThreshold,
            enabled: enabled,
            lastUpdated: block.timestamp
        });
        
        emit ChainConfigUpdated(chainId, chainName, fee, maxDeviation, confidenceThreshold, enabled);
    }
    
    function reportCrossChainData(
        uint256 chainId,
        string memory assetPair,
        uint256 price,
        uint256 confidence,
        bytes32 dataHash
    ) external {
        require(chainConfigs[chainId].enabled, "Chain not enabled");
        require(confidence <= 10000, "Confidence too high");
        require(price > 0, "Invalid price");
        
        // Проверка, что вызывающий является ораклом для этой цепочки
        require(crossChainOracles[chainId].oracleAddress == msg.sender, "Not authorized oracle");
        
        // Обновление статистики оракла
        CrossChainOracle storage oracle = crossChainOracles[chainId];
        oracle.totalReports = oracle.totalReports.add(1);
        oracle.lastReportTime = block.timestamp;
        
        // Создание данных
        CrossChainData storage data = crossChainData[dataHash];
        data.dataHash = dataHash;
        data.assetPair = assetPair;
        data.price = price;
        data.timestamp = block.timestamp;
        data.confidence = confidence;
        data.verified = false;
        data.finalConfidence = 0;
        
        // Добавление отчетчика
        data.reporters.push(msg.sender);
        data.confidenceScores.push(confidence);
        data.timestamps.push(block.timestamp);
        data.chainIds.push(chainId);
        
        emit CrossChainDataReported(dataHash, chainId, assetPair, price, confidence, block.timestamp);
    }
    
    function verifyCrossChainData(
        bytes32 dataHash,
        uint256 chainId,
        uint256[] memory sourceChainIds,
        uint256[] memory sourcePrices,
        uint256[] memory sourceConfidences
    ) external {
        CrossChainData storage data = crossChainData[dataHash];
        require(data.dataHash == dataHash, "Data not found");
        require(!data.verified, "Data already verified");
        require(sourceChainIds.length == sourcePrices.length, "Array length mismatch");
        require(sourceChainIds.length == sourceConfidences.length, "Array length mismatch");
        
        // Проверка данных с разных цепочек
        uint256 totalConfidence = 0;
        uint256 validSources = 0;
        uint256[] memory validPrices = new uint256[](sourceChainIds.length);
        
        for (uint256 i = 0; i < sourceChainIds.length; i++) {
            if (chainConfigs[sourceChainIds[i]].enabled) {
                // Проверка отклонения цены
                uint256 priceDiff = sourcePrices[i] > data.price ? 
                    sourcePrices[i] - data.price : 
                    data.price - sourcePrices[i];
                uint256 maxAllowedDiff = data.price * chainConfigs[sourceChainIds[i]].maxDeviation / 10000;
                
                if (priceDiff <= maxAllowedDiff && sourceConfidences[i] >= chainConfigs[sourceChainIds[i]].confidenceThreshold) {
                    validPrices[validSources] = sourcePrices[i];
                    validSources++;
                    totalConfidence = totalConfidence.add(sourceConfidences[i]);
                }
            }
        }
        
        // Рассчитать финальную уверенность
        uint256 finalConfidence = validSources > 0 ? 
            totalConfidence / validSources : 0;
        
        // Проверить кворум
        uint256 quorum = validSources * 10000 / sourceChainIds.length;
        bool verified = quorum >= 5000; // 50% кворум
        
        if (verified) {
            data.verified = true;
            data.finalConfidence = finalConfidence;
            
            // Обновить агрегированные данные
            AggregatedDataPoint storage aggData = aggregatedData[data.assetPair];
            aggData.assetPair = data.assetPair;
            aggData.price = calculateWeightedAverage(validPrices, validSources);
            aggData.confidence = finalConfidence;
            aggData.timestamp = block.timestamp;
            aggData.sourceCount = validSources;
            
            emit DataAggregated(data.assetPair, aggData.price, finalConfidence, block.timestamp);
        }
        
        emit CrossChainDataVerified(dataHash, chainId, finalConfidence, verified, block.timestamp);
    }
    
    function calculateWeightedAverage(
        uint256[] memory prices,
        uint256 count
    ) internal pure returns (uint256) {
        if (count == 0) return 0;
        
        uint256 sum = 0;
        for (uint256 i = 0; i < count; i++) {
            sum = sum.add(prices[i]);
        }
        
        return sum / count;
    }
    
    function aggregateCrossChainData(
        string memory assetPair,
        uint256[] memory chainIds
    ) external view returns (AggregatedDataPoint memory) {
        return aggregatedData[assetPair];
    }
    
    function getCrossChainOracleInfo(uint256 chainId) external view returns (CrossChainOracle memory) {
        return crossChainOracles[chainId];
    }
    
    function getChainConfig(uint256 chainId) external view returns (ChainConfig memory) {
        return chainConfigs[chainId];
    }
    
    function getCrossChainData(bytes32 dataHash) external view returns (CrossChainData memory) {
        return crossChainData[dataHash];
    }
    
    function getCrossChainDataStats() external view returns (
        uint256 totalOracles,
        uint256 totalDataReports,
        uint256 verifiedData,
        uint256 activeChains
    ) {
        uint256 totalOraclesCount = 0;
        uint256 totalReports = 0;
        uint256 verifiedCount = 0;
        uint256 activeChainCount = 0;
        
        // Подсчет статистики
        for (uint256 i = 1; i < 100; i++) {
            if (crossChainOracles[i].chainId != 0) {
                totalOraclesCount++;
                totalReports = totalReports.add(crossChainOracles[i].totalReports);
            }
            if (chainConfigs[i].chainId != 0 && chainConfigs[i].enabled) {
                activeChainCount++;
            }
        }
        
        // Подсчет верифицированных данных
        for (uint256 i = 0; i < 1000; i++) {
            if (crossChainData[bytes32(i)].dataHash != bytes32(0) && crossChainData[bytes32(i)].verified) {
                verifiedCount++;
            }
        }
        
        return (totalOraclesCount, totalReports, verifiedCount, activeChainCount);
    }
    
    function getCrossChainOracleReliability(uint256 chainId) external view returns (uint256) {
        CrossChainOracle storage oracle = crossChainOracles[chainId];
        if (oracle.totalReports == 0) return 0;
        
        return (oracle.correctReports * 10000) / oracle.totalReports;
    }
    
    function isDataVerified(bytes32 dataHash) external view returns (bool) {
        return crossChainData[dataHash].verified;
    }
    
    function getCrossChainDataHistory(
        string memory assetPair,
        uint256 limit
    ) external view returns (CrossChainData[] memory) {
        // Возвращает историю данных для конкретного актива
        return new CrossChainData[](0);
    }
    
    function getActiveChains() external view returns (uint256[] memory) {
        uint256[] memory activeChains = new uint256[](100);
        uint256 count = 0;
        
        for (uint256 i = 1; i < 100; i++) {
            if (chainConfigs[i].chainId != 0 && chainConfigs[i].enabled) {
                activeChains[count] = i;
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeChains[i];
        }
        
        return result;
    }
    
    function getCrossChainOracleStats() external view returns (
        uint256 totalOracles,
        uint256 activeOracles,
        uint256 totalReports,
        uint256 avgReliability
    ) {
        uint256 totalOraclesCount = 0;
        uint256 activeOraclesCount = 0;
        uint256 totalReportsCount = 0;
        uint256 totalReliability = 0;
        
        for (uint256 i = 1; i < 100; i++) {
            if (crossChainOracles[i].chainId != 0) {
                totalOraclesCount++;
                totalReportsCount = totalReportsCount.add(crossChainOracles[i].totalReports);
                totalReliability = totalReliability.add(crossChainOracles[i].reliabilityScore);
                
                if (crossChainOracles[i].active) {
                    activeOraclesCount++;
                }
            }
        }
        
        uint256 avgReliabilityScore = totalOraclesCount > 0 ? 
            totalReliability / totalOraclesCount : 0;
        
        return (totalOraclesCount, activeOraclesCount, totalReportsCount, avgReliabilityScore);
    }
}
}
