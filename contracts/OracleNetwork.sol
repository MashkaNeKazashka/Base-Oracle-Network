# base-oracle-network/contracts/OracleNetwork.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OracleNetwork is Ownable {
    struct OracleNode {
        address nodeAddress;
        uint256 stakeAmount;
        uint256 lastReportTime;
        bool isActive;
        uint256 reputationScore;
    }
    
    struct DataFeed {
        string feedId;
        address oracleAddress;
        uint256 latestPrice;
        uint256 timestamp;
        uint256 confidence;
        bool isActive;
    }
    
    struct PriceRequest {
        uint256 requestId;
        address requester;
        string assetPair;
        uint256 timestamp;
        bool completed;
        uint256 price;
    }
    
    mapping(address => OracleNode) public oracleNodes;
    mapping(string => DataFeed) public dataFeeds;
    mapping(uint256 => PriceRequest) public priceRequests;
    
    address[] public activeOracles;
    uint256 public minStakeAmount;
    uint256 public requestFee;
    uint256 public nextRequestId;
    
    event OracleRegistered(address indexed node, uint256 stakeAmount);
    event PriceReported(string indexed assetPair, uint256 price, address oracle);
    event PriceRequested(uint256 indexed requestId, address indexed requester, string assetPair);
    event OracleUnregistered(address indexed node);
    
    constructor(
        uint256 _minStakeAmount,
        uint256 _requestFee
    ) {
        minStakeAmount = _minStakeAmount;
        requestFee = _requestFee;
    }
    
    function registerOracle(
        uint256 stakeAmount
    ) external {
        require(stakeAmount >= minStakeAmount, "Insufficient stake amount");
        require(oracleNodes[msg.sender].nodeAddress == address(0), "Already registered");
        
        oracleNodes[msg.sender] = OracleNode({
            nodeAddress: msg.sender,
            stakeAmount: stakeAmount,
            lastReportTime: block.timestamp,
            isActive: true,
            reputationScore: 100
        });
        
        activeOracles.push(msg.sender);
        
        emit OracleRegistered(msg.sender, stakeAmount);
    }
    
    function reportPrice(
        string memory assetPair,
        uint256 price,
        uint256 confidence
    ) external {
        require(oracleNodes[msg.sender].isActive, "Oracle not active");
        require(oracleNodes[msg.sender].stakeAmount >= minStakeAmount, "Insufficient stake");
        
        // Update oracle reputation based on confidence
        if (confidence > 90) {
            oracleNodes[msg.sender].reputationScore = 
                oracleNodes[msg.sender].reputationScore + 1;
        } else if (confidence < 50) {
            oracleNodes[msg.sender].reputationScore = 
                oracleNodes[msg.sender].reputationScore > 10 ? 
                oracleNodes[msg.sender].reputationScore - 10 : 0;
        }
        
        oracleNodes[msg.sender].lastReportTime = block.timestamp;
        
        dataFeeds[assetPair] = DataFeed({
            feedId: assetPair,
            oracleAddress: msg.sender,
            latestPrice: price,
            timestamp: block.timestamp,
            confidence: confidence,
            isActive: true
        });
        
        emit PriceReported(assetPair, price, msg.sender);
    }
    
    function getPrice(
        string memory assetPair
    ) external view returns (uint256, uint256) {
        DataFeed storage feed = dataFeeds[assetPair];
        return (feed.latestPrice, feed.confidence);
    }
    
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
            price: 0
        });
        
        emit PriceRequested(requestId, msg.sender, assetPair);
    }
    
    function unregisterOracle() external {
        require(oracleNodes[msg.sender].nodeAddress != address(0), "Not registered");
        
        // Remove from active oracles array
        for (uint256 i = 0; i < activeOracles.length; i++) {
            if (activeOracles[i] == msg.sender) {
                activeOracles[i] = activeOracles[activeOracles.length - 1];
                activeOracles.pop();
                break;
            }
        }
        
        delete oracleNodes[msg.sender];
        
        emit OracleUnregistered(msg.sender);
    }
}
