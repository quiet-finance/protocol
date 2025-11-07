// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";
import {IGateway} from "./interfaces/IGateway.sol";

using BpsMath for uint256;

contract Gateway is AccessManagedUpgradeable, IGateway {
    /// @custom:storage-location erc7201:quiet-finance.storage.Gateway;
    struct Storage {
        address treasury;
        uint256 nav;
        uint256 mintFeeBps;
        uint256 instantRedeemFeeBps;
        uint256 performanceFeeBps;
        uint256 nextRedeemId;
        uint256 maxRedeemableId;
        mapping(uint256 => RedeemRequestData) redeemRequests;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.Gateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0x6c7c638069ba33d959e62c9f88f4b296b9b20152cbd15f932bd72f3052915f00;

    IERC20 immutable USDC;
    IqUSD immutable qUSD;
    address immutable sqUSD;
    uint256 immutable _scale;

    constructor(IERC20 USDC_, IqUSD qUSD_, address sqUSD_) {
        _disableInitializers();

        USDC = USDC_;
        qUSD = qUSD_;
        sqUSD = sqUSD_;

        uint8 inDecimals = IERC20Metadata(address(USDC_)).decimals();
        uint8 outDecimals = IERC20Metadata(address(qUSD_)).decimals();
        require(outDecimals >= inDecimals);
        _scale = 10 ** (outDecimals - inDecimals);
    }

    function initialize(
        address initialAuthority,
        address treasury_,
        uint256 mintFeeBps_,
        uint256 instantRedeemFeeBps_,
        uint256 performanceFeeBps_
    ) public initializer {
        __AccessManaged_init(initialAuthority);

        mintFeeBps_.validateBps();
        _getStorage().mintFeeBps = mintFeeBps_;
        emit MintFeeUpdated(0, instantRedeemFeeBps_);

        instantRedeemFeeBps_.validateBps();
        _getStorage().instantRedeemFeeBps = instantRedeemFeeBps_;
        emit InstantRedeemFeeUpdated(0, instantRedeemFeeBps_);

        performanceFeeBps_.validateBps();
        _getStorage().performanceFeeBps = performanceFeeBps_;
        emit PerformanceFeeUpdated(0, performanceFeeBps_);

        require(treasury_ != address(0));
        _getStorage().treasury = treasury_;
        emit TreasuryUpdated(address(0), treasury_);
    }

    function issue(address to, uint256 amount) external {
        (uint256 fee, uint256 amountIn) = amount.takeBps(_getStorage().mintFeeBps);
        USDC.transferFrom(msg.sender, address(this), amountIn);
        USDC.transferFrom(msg.sender, _getStorage().treasury, fee);

        uint256 issueAmount = amountIn * _scale;
        qUSD.mint(to, issueAmount);
        emit Issue(msg.sender, to, amount, issueAmount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);

        uint256 amountOut = amount / _scale;
        (uint256 fee, uint256 redeemAmount) = amountOut.takeBps(_getStorage().instantRedeemFeeBps);
        USDC.transfer(_getStorage().treasury, fee);
        USDC.transfer(to, redeemAmount);
        emit InstantRedeem(msg.sender, to, amount, redeemAmount);
    }

    function requestRedeem(address to, uint256 amount) external returns (uint256 requestId) {
        qUSD.burn(msg.sender, amount);

        uint256 amountOut = amount / _scale;
        requestId = ++_getStorage().nextRedeemId;
        _getStorage().redeemRequests[requestId] = RedeemRequestData({
            requester: msg.sender,
            recipient: to,
            amount: amountOut,
            isProcessed: false
        });

        emit RedeemRequest(requestId, msg.sender, to, amount);
    }

    function finishRedeem(uint256 requestId) external {
        RedeemRequestData memory redeemRequest = _getStorage().redeemRequests[requestId];
        require(!redeemRequest.isProcessed, RedeemRequestAlreadyProcessed());
        require(requestId <= _getStorage().maxRedeemableId, RedeemRequestNotReady());

        _getStorage().redeemRequests[requestId].isProcessed = true;
        USDC.transfer(redeemRequest.recipient, redeemRequest.amount);

        emit Redeem(requestId, redeemRequest.recipient, redeemRequest.amount);
    }

    function finishRebalance(uint256 navAfterRebalance, int256 assetsDelta) external restricted {
        uint256 nav = _getStorage().nav;
        if (navAfterRebalance > nav) {
            (uint256 fee, uint256 yield) = (navAfterRebalance - nav).takeBps(_getStorage().performanceFeeBps);
            USDC.transfer(_getStorage().treasury, fee);
            qUSD.mint(sqUSD, yield);
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
        require(id > _getStorage().maxRedeemableId);

        uint256 oldMaxRedeemableId = _getStorage().maxRedeemableId;
        _getStorage().maxRedeemableId = id;
        emit MaxRedeemableIdUpdated(oldMaxRedeemableId, id);
    }

    function setTreasury(address treasury_) external restricted {
        require(treasury_ != address(0));

        address oldTreasury = _getStorage().treasury;
        _getStorage().treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    function setMintFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldFeeBps = _getStorage().mintFeeBps;
        _getStorage().mintFeeBps = feeBps;
        emit MintFeeUpdated(oldFeeBps, feeBps);
    }

    function setInstantRedeemFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldFeeBps = _getStorage().instantRedeemFeeBps;
        _getStorage().instantRedeemFeeBps = feeBps;
        emit InstantRedeemFeeUpdated(oldFeeBps, feeBps);
    }

    function setPerformanceFee(uint256 feeBps) external restricted {
        feeBps.validateBps();

        uint256 oldFeeBps = _getStorage().performanceFeeBps;
        _getStorage().performanceFeeBps = feeBps;
        emit PerformanceFeeUpdated(oldFeeBps, feeBps);
    }

    function getFees()
        external
        view
        returns (address treasury, uint256 mintFeeBps, uint256 instantRedeemFeeBps, uint256 performanceFeeBps)
    {
        treasury = _getStorage().treasury;
        mintFeeBps = _getStorage().mintFeeBps;
        instantRedeemFeeBps = _getStorage().instantRedeemFeeBps;
        performanceFeeBps = _getStorage().performanceFeeBps;
    }

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
