// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";
import {IGateway} from "./interfaces/IGateway.sol";

contract Gateway is AccessManagedUpgradeable, IGateway {
    using BpsMath for uint256;

    IERC20 immutable USDC;
    IqUSD immutable qUSD;
    address immutable sqUSD;

    // Treasury params
    uint256 public successFeeBps;
    address public treasury;

    // Accounting params
    uint256 public nav;

    // Redeem params
    uint256 public instantRedeemFeeBps;
    uint256 internal nextRedeemId;
    uint256 public maxRedeemableId;
    mapping(uint256 => RedeemRequestData) public redeemRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 USDC_, IqUSD qUSD_, address sqUSD_) {
        _disableInitializers();

        USDC = USDC_;
        qUSD = qUSD_;
        sqUSD = sqUSD_;
    }

    function initialize(
        address initialAuthority,
        address treasury_,
        uint256 instantRedeemFeeBps_,
        uint256 successFeeBps_
    ) public initializer {
        __AccessManaged_init(initialAuthority);

        instantRedeemFeeBps_.validateBps();
        instantRedeemFeeBps = instantRedeemFeeBps_;
        emit InstantRedeemFeeUpdated(0, instantRedeemFeeBps_);

        successFeeBps_.validateBps();
        successFeeBps = successFeeBps_;
        emit SuccessFeeUpdated(0, successFeeBps_);

        require(treasury_ != address(0));
        treasury = treasury_;
        emit TreasuryUpdated(address(0), treasury_);
    }

    function issue(address to, uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);
        qUSD.mint(to, amount);

        emit Issue(msg.sender, to, amount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);
        uint256 fee = amount.bpsOf(instantRedeemFeeBps);
        USDC.transfer(treasury, fee);
        USDC.transfer(to, amount - fee);

        emit InstantRedeem(msg.sender, to, amount);
    }

    function requestRedeem(
        address to,
        uint256 amount
    ) external returns (uint256 requestId) {
        qUSD.burn(msg.sender, amount);

        requestId = ++nextRedeemId;
        redeemRequests[requestId] = RedeemRequestData({
            requester: msg.sender,
            recipient: to,
            amount: amount,
            isProcessed: false
        });

        emit RedeemRequest(requestId, msg.sender, to, amount);
    }

    function finishRedeem(uint256 requestId) external {
        RedeemRequestData memory redeemRequest = redeemRequests[requestId];
        require(!redeemRequest.isProcessed, RedeemRequestAlreadyProcessed());
        require(requestId <= maxRedeemableId, RedeemRequestNotReady());

        redeemRequests[requestId].isProcessed = true;
        USDC.transfer(redeemRequest.recipient, redeemRequest.amount);

        emit Redeem(requestId, redeemRequest.recipient, redeemRequest.amount);
    }

    function finishRebalance(
        uint256 navAfterRebalance,
        int256 assetsDelta
    ) external restricted {
        if (navAfterRebalance > nav) {
            uint256 yield = navAfterRebalance - nav;
            uint256 successFee = yield.bpsOf(successFeeBps);
            qUSD.mint(treasury, successFee);
            qUSD.mint(sqUSD, yield - successFee);
        } else if (nav > navAfterRebalance) {
            qUSD.burn(sqUSD, nav - navAfterRebalance);
        }

        if (assetsDelta > 0) {
            USDC.transfer(msg.sender, uint256(assetsDelta));
        } else {
            USDC.transferFrom(msg.sender, address(this), uint256(assetsDelta));
        }
        nav = uint256(int256(navAfterRebalance) + assetsDelta);

        emit RebalanceFinished(navAfterRebalance, assetsDelta);
    }

    function setMaxRedeemableId(uint256 id) external restricted {
        require(id > maxRedeemableId);

        uint256 oldMaxRedeemableId = maxRedeemableId;
        maxRedeemableId = id;
        emit MaxRedeemableIdUpdated(oldMaxRedeemableId, id);
    }

    function setTreasury(address treasury_) external restricted {
        require(treasury_ != address(0));

        address oldTreasury = treasury;
        treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    function setInstantRedeemFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldInstantRedeemFeeBps = instantRedeemFeeBps;
        instantRedeemFeeBps = feeBps;
        emit InstantRedeemFeeUpdated(oldInstantRedeemFeeBps, feeBps);
    }

    function setSuccessFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldSuccessFeeBps = successFeeBps;
        successFeeBps = feeBps;
        emit SuccessFeeUpdated(oldSuccessFeeBps, feeBps);
    }
}
