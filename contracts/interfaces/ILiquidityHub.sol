// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IMintableERC20} from "./IMintableERC20.sol";

interface ILiquidityHub {
    struct RedeemRequestData {
        address requester;
        address recipient;
        uint256 amount;
        bool isProcessed;
    }

    event Issue(address indexed issuer, address indexed recipient, uint256 amount, uint256 issuedAmount);
    event InstantRedeem(address indexed redeemer, address indexed recipient, uint256 amount, uint256 redeemedAmount);
    event RedeemRequest(uint256 requestId, address indexed redeemer, address indexed recipient, uint256 amount);
    event Redeem(uint256 requestId, address indexed recipient, uint256 amount);
    event RebalanceStarted(uint256 oldNav, uint256 navBeforeRebalance);
    event RebalanceFinished(uint256 navBeforeRebalance, uint256 newNav);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event MintFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event InstantRedeemFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PerformanceFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxRedeemableIdUpdated(uint256 oldId, uint256 newId);

    error RedeemRequestAlreadyProcessed();
    error RedeemRequestNotReady();

    function asset() external returns (IERC20);

    function qUSD() external returns (IMintableERC20);

    function sqUSD() external returns (IERC4626);

    function issue(address to, uint256 amount) external returns (uint256 issueAmount);

    function startRebalance(int256 assetsDelta) external;

    function finishRebalance(uint256 newNav) external;
}
