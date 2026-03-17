// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OracleNetwork is Ownable {
    struct Report {
        uint256 price;
        uint256 timestamp;
    }

    mapping(address => bool) public isReporter;
    address[] public reporterList;

    mapping(bytes32 => mapping(address => Report)) public reports;

    uint256 public maxAge = 10 minutes;
    uint256 public minFreshReports = 2;

    event ReporterAdded(address indexed reporter);
    event ReporterRemoved(address indexed reporter);
    event ReportSubmitted(bytes32 indexed assetId, address indexed reporter, uint256 price, uint256 timestamp);
    event MaxAgeUpdated(uint256 newMaxAge);
    event MinFreshReportsUpdated(uint256 newMinFreshReports);

    constructor(address[] memory reporters_) Ownable(msg.sender) {
        for (uint256 i = 0; i < reporters_.length; i++) {
            _addReporter(reporters_[i]);
        }
    }

    function addReporter(address reporter) external onlyOwner {
        _addReporter(reporter);
    }

    function _addReporter(address reporter) internal {
        require(reporter != address(0), "zero");
        require(!isReporter[reporter], "exists");

        isReporter[reporter] = true;
        reporterList.push(reporter);

        emit ReporterAdded(reporter);
    }

    function removeReporter(address reporter) external onlyOwner {
        require(isReporter[reporter], "not reporter");
        isReporter[reporter] = false;

        emit ReporterRemoved(reporter);
    }

    function setMaxAge(uint256 newMaxAge) external onlyOwner {
        require(newMaxAge > 0, "zero");
        maxAge = newMaxAge;
        emit MaxAgeUpdated(newMaxAge);
    }

    function setMinFreshReports(uint256 newMinFreshReports) external onlyOwner {
        require(newMinFreshReports > 0, "zero");
        minFreshReports = newMinFreshReports;
        emit MinFreshReportsUpdated(newMinFreshReports);
    }

    function submitReport(bytes32 assetId, uint256 price) external {
        require(isReporter[msg.sender], "not reporter");
        require(price > 0, "price=0");

        reports[assetId][msg.sender] = Report({
            price: price,
            timestamp: block.timestamp
        });

        emit ReportSubmitted(assetId, msg.sender, price, block.timestamp);
    }

    function getLatestReport(bytes32 assetId, address reporter)
        external
        view
        returns (
            uint256 price,
            uint256 timestamp,
            bool fresh
        )
    {
        Report memory rep = reports[assetId][reporter];
        return (
            rep.price,
            rep.timestamp,
            rep.price > 0 && block.timestamp <= rep.timestamp + maxAge
        );
    }

    function getMedianPrice(bytes32 assetId) external view returns (uint256) {
        uint256[] memory freshPrices = new uint256[](reporterList.length);
        uint256 count = 0;

        for (uint256 i = 0; i < reporterList.length; i++) {
            address reporter = reporterList[i];
            if (!isReporter[reporter]) continue;

            Report memory rep = reports[assetId][reporter];
            if (rep.price == 0) continue;
            if (block.timestamp > rep.timestamp + maxAge) continue;

            freshPrices[count] = rep.price;
            count++;
        }

        require(count >= minFreshReports, "not enough reports");

        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                if (freshPrices[j] < freshPrices[i]) {
                    uint256 tmp = freshPrices[i];
                    freshPrices[i] = freshPrices[j];
                    freshPrices[j] = tmp;
                }
            }
        }

        if (count % 2 == 1) {
            return freshPrices[count / 2];
        }

        uint256 a = freshPrices[(count / 2) - 1];
        uint256 b = freshPrices[count / 2];
        return (a + b) / 2;
    }

    function reportersCount() external view returns (uint256) {
        return reporterList.length;
    }
}
