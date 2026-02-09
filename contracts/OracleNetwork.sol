// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  Base oracle:
  - Multiple reporters
  - Median price aggregation
*/

import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseMedianOracle is Ownable {
    mapping(address => bool) public isReporter;
    address[] public reporters;

    // assetId => reporter => price
    mapping(bytes32 => mapping(address => uint256)) public reports;

    event ReporterAdded(address reporter);
    event ReporterRemoved(address reporter);
    event PriceReported(bytes32 indexed assetId, address indexed reporter, uint256 price);

    constructor(address[] memory _reporters) Ownable(msg.sender) {
        for (uint256 i = 0; i < _reporters.length; i++) _addReporter(_reporters[i]);
        require(reporters.length >= 3, "need >=3 reporters");
    }

    function addReporter(address r) external onlyOwner { _addReporter(r); }
    function _addReporter(address r) internal {
        require(r != address(0), "zero");
        require(!isReporter[r], "dup");
        isReporter[r] = true;
        reporters.push(r);
        emit ReporterAdded(r);
    }

    function removeReporter(address r) external onlyOwner {
        require(isReporter[r], "not reporter");
        isReporter[r] = false;
        emit ReporterRemoved(r);
        // educational: not removing from array to keep code simple
    }

    function report(bytes32 assetId, uint256 price) external {
        require(isReporter[msg.sender], "not reporter");
        require(price > 0, "price=0");
        reports[assetId][msg.sender] = price;
        emit PriceReported(assetId, msg.sender, price);
    }

    function getMedian(bytes32 assetId) external view returns (uint256) {
        uint256 n = reporters.length;
        uint256[] memory vals = new uint256[](n);
        uint256 k;

        for (uint256 i = 0; i < n; i++) {
            address r = reporters[i];
            if (!isReporter[r]) continue;
            uint256 v = reports[assetId][r];
            if (v == 0) continue;
            vals[k++] = v;
        }
        require(k >= 3, "not enough reports");

        // sort first k elements (selection sort, educational)
        for (uint256 i = 0; i < k; i++) {
            uint256 minI = i;
            for (uint256 j = i + 1; j < k; j++) {
                if (vals[j] < vals[minI]) minI = j;
            }
            (vals[i], vals[minI]) = (vals[minI], vals[i]);
        }

        if (k % 2 == 1) return vals[k / 2];
        return (vals[(k / 2) - 1] + vals[k / 2]) / 2;
    }
}
