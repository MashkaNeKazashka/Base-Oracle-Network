// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakedToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract LiquidStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlying;
    IStakedToken public immutable stToken;

    uint256 public cooldown = 2 days;

    struct RedeemRequest {
        uint256 amount;
        uint256 readyAt;
    }
    mapping(address => RedeemRequest) public redeems;

    event Deposited(address indexed user, uint256 amount);
    event RedeemRequested(address indexed user, uint256 amount, uint256 readyAt);
    event RedeemCancelled(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    event Recovered(address indexed token, address indexed to, uint256 amount);

    constructor(address _underlying, address _stToken) Ownable(msg.sender) {
        require(_underlying != address(0) && _stToken != address(0), "zero");
        underlying = IERC20(_underlying);
        stToken = IStakedToken(_stToken);
    }

    function setCooldown(uint256 _cooldown) external onlyOwner {
        cooldown = _cooldown;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        stToken.mint(msg.sender, amount);
        emit Deposited(msg.sender, amount);
    }

    function requestRedeem(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        RedeemRequest storage r = redeems[msg.sender];
        require(r.amount == 0, "pending");

        IERC20(address(stToken)).safeTransferFrom(msg.sender, address(this), amount);

        r.amount = amount;
        r.readyAt = block.timestamp + cooldown;

        emit RedeemRequested(msg.sender, amount, r.readyAt);
    }

    function cancelRedeem() external nonReentrant {
        RedeemRequest storage r = redeems[msg.sender];
        require(r.amount > 0, "no request");

        uint256 amount = r.amount;
        r.amount = 0;
        r.readyAt = 0;

        IERC20(address(stToken)).safeTransfer(msg.sender, amount);
        emit RedeemCancelled(msg.sender, amount);
    }

    function redeem() external nonReentrant {
        RedeemRequest storage r = redeems[msg.sender];
        require(r.amount > 0, "no request");
        require(block.timestamp >= r.readyAt, "not ready");

        uint256 amount = r.amount;
        r.amount = 0;
        r.readyAt = 0;

        stToken.burn(address(this), amount);
        underlying.safeTransfer(msg.sender, amount);

        emit Redeemed(msg.sender, amount);
    }

    // Improvement
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(underlying), "no underlying");
        require(token != address(stToken), "no stToken");
        require(to != address(0), "to=0");
        IERC20(token).safeTransfer(to, amount);
        emit Recovered(token, to, amount);
    }
}
