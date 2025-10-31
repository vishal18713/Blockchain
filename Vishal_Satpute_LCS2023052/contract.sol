// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingProtocol is Ownable, ReentrancyGuard {
    IERC20 public stableToken;

    struct BorrowInfo {
        address user;
        uint256 borrowedAmount;
        uint256 stakedCollateral;
        uint256 rateOfInterest;
        bool isSettled;
    }

    mapping(address => uint256) public providerBalance;
    mapping(address => BorrowInfo) public activeLoans;

    event TokensSupplied(address indexed provider, uint256 value);
    event TokensBorrowed(address indexed user, uint256 value, uint256 collateral);
    event LoanCleared(address indexed user, uint256 totalPaid);

    constructor(address tokenAddress) Ownable(msg.sender) {
        stableToken = IERC20(tokenAddress);
    }


    function supply(uint256 value) external nonReentrant {
        require(value > 0, "Supply amount must be positive");
        stableToken.transferFrom(msg.sender, address(this), value);
        providerBalance[msg.sender] += value;
        emit TokensSupplied(msg.sender, value);
    }


    function takeLoan(uint256 value) external payable nonReentrant {
        require(activeLoans[msg.sender].borrowedAmount == 0, "Existing loan active");
        require(msg.value > 0, "Collateral must be sent");

        activeLoans[msg.sender] = BorrowInfo({
            user: msg.sender,
            borrowedAmount: value,
            stakedCollateral: msg.value,
            rateOfInterest: 10,
            isSettled: false
        });

        stableToken.transfer(msg.sender, value);
        emit TokensBorrowed(msg.sender, value, msg.value);
    }


    function settleLoan() external nonReentrant {
        BorrowInfo storage loanData = activeLoans[msg.sender];
        require(!loanData.isSettled, "Loan already settled");
        require(loanData.borrowedAmount > 0, "No loan found");

        uint256 interest = (loanData.borrowedAmount * loanData.rateOfInterest) / 100;
        uint256 amountToRepay = loanData.borrowedAmount + interest;

        stableToken.transferFrom(msg.sender, address(this), amountToRepay);
        loanData.isSettled = true;

        payable(msg.sender).transfer(loanData.stakedCollateral);
        emit LoanCleared(msg.sender, amountToRepay);
    }

    function withdrawEarnings(address receiver, uint256 value) external onlyOwner {
        stableToken.transfer(receiver, value);
    }
}
