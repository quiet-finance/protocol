// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IMintableERC20} from "./IMintableERC20.sol";
import {Bps} from "../libraries/BpsMath.sol";

interface ILiquidityHub {
    struct RedeemData {
        address recipient;
        uint256 assetAmount;
        uint256 cumAssetAmount;
        bool isProcessed;
    }

    // user actions
    event Issue(address indexed issuer, address indexed recipient, uint256 underlyingAmount, uint256 assetAmount);
    event InstantRedeem(
        address indexed redeemer,
        address indexed recipient,
        uint256 assetAmount,
        uint256 underlyingAmount
    );
    event RedeemRequest(uint256 requestId, address indexed redeemer, address indexed recipient, uint256 assetAmount);
    event Redeem(uint256 requestId, address indexed recipient, uint256 underlyingAmount);

    // system actions
    event RebalanceStarted(uint256 deployedUnderlying);
    event RebalanceFinished(uint256 deployedUnderlying);
    event RedeemsProcessed(uint256 lastProcessedRedeemId);

    // config updates
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event MintFeeUpdated(Bps oldFee, Bps newFee);
    event InstantRedeemFeeUpdated(Bps oldFee, Bps newFee);
    event PerformanceFeeUpdated(Bps oldFee, Bps newFee);

    error RedeemRequestAlreadyProcessed();
    error RedeemRequestNotReady();
    error NoAvailableUnderlyingAmount();

    // user actions
    function issue(address recipient, uint256 underlyingAmount) external returns (uint256 assetAmount);

    function redeemInstant(address recipient, uint256 assetAmount) external returns (uint256 underlyingAmount);

    function requestRedeem(address recipient, uint256 assetAmount) external returns (uint256 redeemId);

    // system actions
    function startRebalance(int256 underlyingToDeploy) external;

    function finishRebalance(uint256 deployedAssets) external;

    // getters
    function underlying() external returns (IERC20);

    function asset() external returns (IMintableERC20);

    function vault() external returns (IERC4626);
}
