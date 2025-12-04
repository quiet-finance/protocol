// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {BpsMath} from "./libraries/BpsMath.sol";
import {Scale} from "./libraries/Scale.sol";
import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {ILiquidityHub} from "./interfaces/ILiquidityHub.sol";

using BpsMath for uint256;
using Scale for uint256;
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
    IMintableERC20 public immutable receipt;
    IERC4626 public immutable share;
    uint256 immutable _scale;

    constructor(IERC20 asset_, IMintableERC20 receipt_, IERC4626 share_) {
        _disableInitializers();

        require(address(share_.asset()) == address(receipt_));
        asset = asset_;
        receipt = receipt_;
        share = share_;
        _scale = Scale.calculate({asset: address(asset_), receipt: address(receipt_)});
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

    function issue(address to, uint256 assetAmount) external returns (uint256 receiptAmount) {
        (uint256 fee, uint256 amount) = assetAmount.takeBps(_getStorage().mintFeeBps);
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.safeTransferFrom(msg.sender, _getStorage().treasury, fee);

        receiptAmount = amount.asReceiptAmount(_scale);
        receipt.mint(to, receiptAmount);
        emit Issue(msg.sender, to, assetAmount, receiptAmount);
    }

    function redeemInstant(address to, uint256 receiptAmount) external {
        receipt.burn(msg.sender, receiptAmount);

        uint256 amount = receiptAmount.asAssetAmount(_scale);
        (uint256 fee, uint256 assetAmount) = amount.takeBps(_getStorage().instantRedeemFeeBps);
        asset.safeTransfer(_getStorage().treasury, fee);
        asset.safeTransfer(to, assetAmount);
        emit InstantRedeem(msg.sender, to, receiptAmount, assetAmount);
    }

    function requestRedeem(address to, uint256 receiptAmount) external returns (uint256 requestId) {
        receipt.burn(msg.sender, receiptAmount);

        requestId = ++_getStorage().nextRedeemId;
        _getStorage().redeemRequests[requestId] = RedeemRequestData({
            recipient: to,
            receiptAmount: receiptAmount,
            isProcessed: false
        });

        emit RedeemRequest(requestId, msg.sender, to, receiptAmount);
    }

    function finishRedeem(uint256 requestId) external {
        RedeemRequestData memory redeemRequest = _getStorage().redeemRequests[requestId];
        require(!redeemRequest.isProcessed, RedeemRequestAlreadyProcessed());
        require(requestId <= _getStorage().maxRedeemableId, RedeemRequestNotReady());

        uint256 assetAmount = redeemRequest.receiptAmount.asAssetAmount(_scale);
        _getStorage().redeemRequests[requestId].isProcessed = true;
        asset.transfer(redeemRequest.recipient, assetAmount);

        emit Redeem(requestId, redeemRequest.recipient, assetAmount);
    }

    function startRebalance(int256 assetsDelta) external restricted {
        if (assetsDelta > 0) {
            asset.transfer(msg.sender, uint256(assetsDelta).asAssetAmount(_scale));
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
            // Fee transfer could fail, if there is no such assets on Liquidity Hub.
            // It's ok, rebalancer should maintain required amount for it.
            asset.transfer(_getStorage().treasury, fee.asAssetAmount(_scale));
            receipt.mint(address(share), yield);
        } else if (navBeforeRebalance > newNav) {
            receipt.burn(address(share), navBeforeRebalance - newNav);
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

    function getRedeemRequest(uint256 requestId) external view returns (RedeemRequestData memory) {
        return _getStorage().redeemRequests[requestId];
    }

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
