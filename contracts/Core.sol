// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";

struct RedeemRequest {
    address requester;
    uint256 amount;
    bool isProcessed;
}

contract Core is AccessManagedUpgradeable {
    using BpsMath for uint256;

    IqUSD immutable qUSD;
    IERC20 immutable sqUSD;
    IERC20 immutable USDC;

    // Treasury params
    uint256 successFeeBps;
    address treasury;

    //
    uint256 storedNav;

    // Redeem params
    uint256 instantRedeemFeeBps;
    uint256 nextRedeemId;
    uint256 maxRedeemableId;
    mapping(uint256 => RedeemRequest) public redeemRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IqUSD qUSD_, IERC20 USDC_) {
        _disableInitializers();

        qUSD = qUSD_;
        USDC = USDC_;
    }

    function initialize(
        address initialAuthority,
        address treasury_
    ) public initializer {
        __AccessManaged_init(initialAuthority);

        instantRedeemFeeBps = 300; // 3% by default
        treasury = treasury_;
    }

    function issue(address to, uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);
        qUSD.mint(to, amount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);

        uint256 fee = amount.bpsOf(instantRedeemFeeBps);
        USDC.transfer(treasury, fee);
        USDC.transfer(to, amount - fee);
    }

    function requestRedeem(uint256 amount) external {
        qUSD.burn(msg.sender, amount);
        redeemRequests[++nextRedeemId] = RedeemRequest({
            requester: msg.sender,
            amount: amount,
            isProcessed: false
        });
    }

    function setMaxRedeemableId(uint256 maxRedeemableId_) external restricted {
        require(maxRedeemableId_ > maxRedeemableId);
        maxRedeemableId = maxRedeemableId_;
    }

    function setTreasury(address treasury_) external restricted {
        treasury = treasury_;
    }

    function setInstantRedeemFeeBps(
        uint256 instantRedeemFeeBps_
    ) external restricted {
        instantRedeemFeeBps_.checkIsBps();
        instantRedeemFeeBps = instantRedeemFeeBps_;
    }

    function finishRedeem(uint256 requestId, address to) external {
        RedeemRequest storage redeemRequest = redeemRequests[requestId];
        require(!redeemRequest.isProcessed);
        require(redeemRequest.requester == msg.sender);
        require(requestId <= maxRedeemableId);

        redeemRequest.isProcessed = true;
        USDC.transfer(to, redeemRequest.amount);
    }

    function finishRebalance(
        uint256 nav,
        int256 assetsDelta
    ) external restricted {
        if (nav > storedNav) {
            uint256 yield = nav - storedNav;
            uint256 successFee = yield.bpsOf(successFeeBps);
            qUSD.mint(treasury, successFee);
            qUSD.mint(address(sqUSD), yield - successFee);
        } else if (nav < storedNav) {
            qUSD.burn(address(sqUSD), storedNav - nav);
        }

        if (assetsDelta > 0) {
            USDC.transfer(msg.sender, uint256(assetsDelta));
            storedNav = nav + uint256(assetsDelta);
        } else {
            USDC.transferFrom(msg.sender, address(this), uint256(assetsDelta));
            storedNav = nav + uint256(assetsDelta);
        }
    }
}
