// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IGateway {
    struct RedeemRequestData {
        address requester;
        address recipient;
        uint256 amount;
        bool isProcessed;
    }

    event Issue(address indexed issuer, address indexed recipient, uint256 amount);
    event InstantRedeem(address indexed redeemer, address indexed recipient, uint256 amount);
    event RedeemRequest(uint256 requestId, address indexed redeemer, address indexed recipient, uint256 amount);
    event Redeem(uint256 requestId, address indexed recipient, uint256 amount);
    event RebalanceFinished(uint256 navAfterRebalance, int256 assetsDelta);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event InstantRedeemFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event SuccessFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event MaxRedeemableIdUpdated(uint256 oldId, uint256 newId);

    error RedeemRequestAlreadyProcessed();
    error RedeemRequestNotReady();
}
