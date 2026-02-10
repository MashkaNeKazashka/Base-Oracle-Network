// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OracleNetwork is Ownable {
    mapping(address => bool) public isReporter;
    address[] public reporters;

    uint256 public maxAge = 10 minutes;
 
    struct Report {
        uint256 price;
        uint256 timestamp;
    }

    mapping(bytes32 => mapping(address => Report)) public reports;

    event PriceReported(bytes32 indexed assetId, address indexed reporter, uint256 price, uint256 timestamp);
    event MaxAgeUpdated(uint256 maxAge);

    constructor(address[] memory _reporters) Ownable(msg.sender) {
        for (uint256 i = 0; i < _reporters.length; i++) {
            address r = _reporters[i];
            require(r != address(0), "zero");
            require(!isReporter[r], "dup");
            isReporter[r] = true;
            reporters.push(r);
        }
    }

    function setMaxAge(uint256 _maxAge) external onlyOwner {
        maxAge = _maxAge;
        emit MaxAgeUpdated(_maxAge);
    }

    function report(bytes32 assetId, uint256 price) external {
        require(isReporter[msg.sender], "not reporter");
        require(price > 0, "price=0");
        reports[assetId][msg.sender] = Report(price, block.timestamp);
        emit PriceReported(assetId, msg.sender, price, block.timestamp);
    }

    function getMedian(bytes32 assetId) external view returns (uint256) {
        uint256 n = reporters.length;
        uint256[] memory vals = new uint256[](n);
        uint256 k;

        for (uint256 i = 0; i < n; i++) {
            address r = reporters[i];
            if (!isReporter[r]) continue;
            Report memory rep = reports[assetId][r];
            if (rep.price == 0) continue;
            if (block.timestamp - rep.timestamp > maxAge) continue;
            vals[k++] = rep.price;
        }
        require(k >= 3, "not enough fresh");

        for (uint256 i = 0; i < k; i++) {
            uint256 minI = i;
            for (uint256 j = i + 1; j < k; j++) if (vals[j] < vals[minI]) minI = j;
            (vals[i], vals[minI]) = (vals[minI], vals[i]);
        }

        if (k % 2 == 1) return vals[k / 2];
        return (vals[(k / 2) - 1] + vals[k / 2]) / 2;
    }
}
