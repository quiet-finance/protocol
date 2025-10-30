// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";
import {IGateway} from "./interfaces/IGateway.sol";

using BpsMath for uint256;

contract Gateway is AccessManagedUpgradeable, IGateway {
    /// @custom:storage-location erc7201:quiet-finance.storage.Gateway;
    struct GatewayStorage {
        uint256 successFeeBps;
        address treasury;
        uint256 nav;
        uint256 instantRedeemFeeBps;
        uint256 nextRedeemId;
        uint256 maxRedeemableId;
        mapping(uint256 => RedeemRequestData) redeemRequests;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.Gateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GATEWAY_STORAGE_LOCATION =
        0x6c7c638069ba33d959e62c9f88f4b296b9b20152cbd15f932bd72f3052915f00;

    IERC20 immutable USDC;
    IqUSD immutable qUSD;
    address immutable sqUSD;

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
        _getGatewayStorage().instantRedeemFeeBps = instantRedeemFeeBps_;
        emit InstantRedeemFeeUpdated(0, instantRedeemFeeBps_);

        successFeeBps_.validateBps();
        _getGatewayStorage().successFeeBps = successFeeBps_;
        emit SuccessFeeUpdated(0, successFeeBps_);

        require(treasury_ != address(0));
        _getGatewayStorage().treasury = treasury_;
        emit TreasuryUpdated(address(0), treasury_);
    }

    function issue(address to, uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);
        qUSD.mint(to, amount);

        emit Issue(msg.sender, to, amount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);
        uint256 fee = amount.bpsOf(_getGatewayStorage().instantRedeemFeeBps);
        USDC.transfer(_getGatewayStorage().treasury, fee);
        USDC.transfer(to, amount - fee);

        emit InstantRedeem(msg.sender, to, amount);
    }

    function requestRedeem(address to, uint256 amount) external returns (uint256 requestId) {
        qUSD.burn(msg.sender, amount);

        requestId = ++_getGatewayStorage().nextRedeemId;
        _getGatewayStorage().redeemRequests[requestId] = RedeemRequestData({
            requester: msg.sender,
            recipient: to,
            amount: amount,
            isProcessed: false
        });

        emit RedeemRequest(requestId, msg.sender, to, amount);
    }

    function finishRedeem(uint256 requestId) external {
        RedeemRequestData memory redeemRequest = _getGatewayStorage().redeemRequests[requestId];
        require(!redeemRequest.isProcessed, RedeemRequestAlreadyProcessed());
        require(requestId <= _getGatewayStorage().maxRedeemableId, RedeemRequestNotReady());

        _getGatewayStorage().redeemRequests[requestId].isProcessed = true;
        USDC.transfer(redeemRequest.recipient, redeemRequest.amount);

        emit Redeem(requestId, redeemRequest.recipient, redeemRequest.amount);
    }

    function finishRebalance(uint256 navAfterRebalance, int256 assetsDelta) external restricted {
        uint256 nav = _getGatewayStorage().nav;
        if (navAfterRebalance > nav) {
            uint256 yield = navAfterRebalance - nav;
            uint256 successFee = yield.bpsOf(_getGatewayStorage().successFeeBps);
            qUSD.mint(_getGatewayStorage().treasury, successFee);
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
        require(id > _getGatewayStorage().maxRedeemableId);

        uint256 oldMaxRedeemableId = _getGatewayStorage().maxRedeemableId;
        _getGatewayStorage().maxRedeemableId = id;
        emit MaxRedeemableIdUpdated(oldMaxRedeemableId, id);
    }

    function setTreasury(address treasury_) external restricted {
        require(treasury_ != address(0));

        address oldTreasury = _getGatewayStorage().treasury;
        _getGatewayStorage().treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    function setInstantRedeemFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldInstantRedeemFeeBps = _getGatewayStorage().instantRedeemFeeBps;
        _getGatewayStorage().instantRedeemFeeBps = feeBps;
        emit InstantRedeemFeeUpdated(oldInstantRedeemFeeBps, feeBps);
    }

    function setSuccessFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldSuccessFeeBps = _getGatewayStorage().successFeeBps;
        _getGatewayStorage().successFeeBps = feeBps;
        emit SuccessFeeUpdated(oldSuccessFeeBps, feeBps);
    }

    function treasury() external view returns (address) {
        return _getGatewayStorage().treasury;
    }

    function instantRedeemFeeBps() external view returns (uint256) {
        return _getGatewayStorage().instantRedeemFeeBps;
    }

    function _getGatewayStorage() private pure returns (GatewayStorage storage $) {
        assembly {
            $.slot := GATEWAY_STORAGE_LOCATION
        }
    }
}
