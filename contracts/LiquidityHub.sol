// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {ILiquidityHub} from "./interfaces/ILiquidityHub.sol";

using BpsMath for uint256;
using SafeERC20 for IERC20;

contract LiquidityHub is AccessManagedUpgradeable, ILiquidityHub {
    /// @custom:storage-location erc7201:quiet-finance.storage.LiquidityHub;
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

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.LiquidityHub")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0xe8b4e6acc11b7ea32c9576c2f633d68d5883bbaf6e0350cabf1975ea66cfba00;

    IERC20 public immutable asset;
    IMintableERC20 public immutable qUSD;
    IERC4626 public immutable sqUSD;
    uint256 immutable _scale;

    constructor(IERC20 asset_, IMintableERC20 qUSD_, IERC4626 sqUSD_) {
        _disableInitializers();

        require(address(sqUSD_.asset()) == address(qUSD_));
        asset = asset_;
        qUSD = qUSD_;
        sqUSD = sqUSD_;

        uint8 inDecimals = IERC20Metadata(address(asset_)).decimals();
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

    function issue(address to, uint256 amount) external returns (uint256 issueAmount) {
        (uint256 fee, uint256 amountIn) = amount.takeBps(_getStorage().mintFeeBps);
        asset.safeTransferFrom(msg.sender, address(this), amountIn);
        asset.safeTransferFrom(msg.sender, _getStorage().treasury, fee);

        issueAmount = amountIn * _scale;
        qUSD.mint(to, issueAmount);
        emit Issue(msg.sender, to, amount, issueAmount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);

        uint256 amountOut = amount / _scale;
        (uint256 fee, uint256 redeemAmount) = amountOut.takeBps(_getStorage().instantRedeemFeeBps);
        asset.safeTransfer(_getStorage().treasury, fee);
        asset.safeTransfer(to, redeemAmount);
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
        asset.transfer(redeemRequest.recipient, redeemRequest.amount);

        emit Redeem(requestId, redeemRequest.recipient, redeemRequest.amount);
    }

    function startRebalance(int256 assetsDelta) external restricted {
        if (assetsDelta > 0) {
            asset.transfer(msg.sender, uint256(assetsDelta));
        }

        uint256 oldNav = _getStorage().nav;
        uint256 navBeforeRebalance = uint256(int256(oldNav) + assetsDelta);
        _getStorage().nav = navBeforeRebalance;

        emit RebalanceStarted(oldNav, navBeforeRebalance);
    }

    function finishRebalance(uint256 newNav) external restricted {
        uint256 navBeforeRebalance = _getStorage().nav;
        if (newNav > navBeforeRebalance) {
            (uint256 fee, uint256 yield) = (newNav - navBeforeRebalance).takeBps(_getStorage().performanceFeeBps);
            asset.transfer(_getStorage().treasury, fee);
            qUSD.mint(address(sqUSD), yield);
        } else if (navBeforeRebalance > newNav) {
            qUSD.burn(address(sqUSD), navBeforeRebalance - newNav);
        }
        _getStorage().nav = newNav;

        emit RebalanceFinished(navBeforeRebalance, newNav);
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
