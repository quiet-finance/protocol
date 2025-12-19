// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Bps} from "./libraries/BpsMath.sol";
import {Scale} from "./libraries/Scale.sol";
import {IMintableERC20} from "./interfaces/IMintableERC20.sol";
import {ILiquidityHub} from "./interfaces/ILiquidityHub.sol";

using Scale for uint256;
using Scale for int256;
using SafeERC20 for IERC20;

contract LiquidityHub is AccessManagedUpgradeable, ILiquidityHub {
    /// @custom:storage-location erc7201:quiet-finance.storage.LiquidityHub;
    struct Storage {
        address treasury;
        Bps mintFee;
        Bps instantRedeemFee;
        Bps performanceFee;
        //

        uint256 deployedAssets;
        uint256 lastRedeemId;
        uint256 lastProcessedRedeemId;
        uint256 processedRedeems;
        mapping(uint256 => RedeemData) redeems;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.LiquidityHub")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0xe8b4e6acc11b7ea32c9576c2f633d68d5883bbaf6e0350cabf1975ea66cfba00;

    IERC20 public immutable underlying;
    IMintableERC20 public immutable asset;
    IERC4626 public immutable vault;
    uint256 immutable _scale;

    constructor(IERC20 underlying_, IMintableERC20 asset_, IERC4626 vault_) {
        _disableInitializers();

        require(address(vault_.asset()) == address(asset_));
        underlying = underlying_;
        asset = asset_;
        vault = vault_;
        _scale = Scale.calculate({underlying: address(underlying_), asset: address(asset_)});
    }

    function initialize(
        address initialAuthority,
        address treasury,
        Bps mintFee,
        Bps instantRedeemFee,
        Bps performanceFee
    ) public initializer {
        __AccessManaged_init(initialAuthority);

        Storage storage $ = _getStorage();

        $.mintFee = mintFee.validate();
        emit MintFeeUpdated(Bps.wrap(0), mintFee);

        $.instantRedeemFee = instantRedeemFee.validate();
        emit InstantRedeemFeeUpdated(Bps.wrap(0), instantRedeemFee);

        $.performanceFee = performanceFee.validate();
        emit PerformanceFeeUpdated(Bps.wrap(0), performanceFee);

        require(treasury != address(0));
        $.treasury = treasury;
        emit TreasuryUpdated(address(0), treasury);
    }

    function issue(address to, uint256 underlyingAmount) external returns (uint256 assetAmount) {
        Storage storage $ = _getStorage();

        (uint256 fee, uint256 underlyingAmountWithoutFee) = $.mintFee.splitOf(underlyingAmount);
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmountWithoutFee);
        underlying.safeTransferFrom(msg.sender, $.treasury, fee);

        assetAmount = underlyingAmountWithoutFee.asAssetAmount(_scale);
        asset.mint(to, assetAmount);
        emit Issue(msg.sender, to, underlyingAmount, assetAmount);
    }

    function redeemInstant(address to, uint256 assetAmount) external returns (uint256 underlyingAmount) {
        Storage storage $ = _getStorage();

        asset.burn(msg.sender, assetAmount);
        uint256 fee;
        (fee, underlyingAmount) = $.instantRedeemFee.splitOf(assetAmount.asUnderlyingAmount(_scale));
        _checkIfUnderlyingAvailable(underlyingAmount + fee);

        underlying.safeTransfer($.treasury, fee);
        underlying.safeTransfer(to, underlyingAmount);
        emit InstantRedeem(msg.sender, to, assetAmount, underlyingAmount);
    }

    function requestRedeem(address to, uint256 assetAmount) external returns (uint256 redeemId) {
        Storage storage $ = _getStorage();

        asset.burn(msg.sender, assetAmount);

        redeemId = ++$.lastRedeemId;
        $.redeems[redeemId] = RedeemData({
            recipient: to,
            assetAmount: assetAmount,
            cumAssetAmount: assetAmount + $.redeems[redeemId - 1].cumAssetAmount,
            isProcessed: false
        });
        emit RedeemRequest(redeemId, msg.sender, to, assetAmount);
    }

    function finishRedeem(uint256 redeemId) external {
        Storage storage $ = _getStorage();
        RedeemData memory r = $.redeems[redeemId];

        require(!r.isProcessed, RedeemRequestAlreadyProcessed());
        require(redeemId <= $.lastProcessedRedeemId, RedeemRequestNotReady());
        $.redeems[redeemId].isProcessed = true;

        uint256 underlyingAmount = r.assetAmount.asUnderlyingAmount(_scale);
        underlying.transfer(r.recipient, underlyingAmount);
        emit Redeem(redeemId, r.recipient, underlyingAmount);
    }

    function startRebalance(int256 underlyingToDeploy) external restricted {
        Storage storage $ = _getStorage();

        if (underlyingToDeploy > 0) {
            uint256 underlyingAmount = uint256(underlyingToDeploy);
            _checkIfUnderlyingAvailable(underlyingAmount);

            underlying.transfer(msg.sender, underlyingAmount);
        }

        uint256 deployedAssets = uint256(int256($.deployedAssets) + underlyingToDeploy.asAssetAmount(_scale));
        $.deployedAssets = deployedAssets;
        emit RebalanceStarted(deployedAssets);
    }

    function finishRebalance(uint256 deployedAssets) external restricted {
        Storage storage $ = _getStorage();

        uint256 deployedAssetsBefore = $.deployedAssets;
        if (deployedAssets > deployedAssetsBefore) {
            (uint256 fee, uint256 yield) = $.performanceFee.splitOf(deployedAssets - deployedAssetsBefore);
            // 1. Fee transfer could fail, if there is no such underlyings on Liquidity Hub,
            // rebalancer should maintain required amount for it.
            // 2. Maybe there is some dust, which didn't sends to treasury because of decimals conversions.
            underlying.transfer($.treasury, fee.asUnderlyingAmount(_scale));
            asset.mint(address(vault), yield);
        } else if (deployedAssetsBefore > deployedAssets) {
            asset.burn(address(vault), deployedAssetsBefore - deployedAssets);
        }
        $.deployedAssets = deployedAssets;

        emit RebalanceFinished(deployedAssets);
    }

    function processRedeems(uint256 lastProcessedRedeemId) external restricted {
        Storage storage $ = _getStorage();

        require(lastProcessedRedeemId > $.lastProcessedRedeemId);
        $.lastProcessedRedeemId = lastProcessedRedeemId;
        emit RedeemsProcessed(lastProcessedRedeemId);
    }

    function setTreasury(address treasury_) external restricted {
        require(treasury_ != address(0));

        address oldTreasury = _getStorage().treasury;
        _getStorage().treasury = treasury_;
        emit TreasuryUpdated(oldTreasury, treasury_);
    }

    function setMintFee(Bps fee) external restricted {
        Bps oldFee = _getStorage().mintFee;
        _getStorage().mintFee = fee.validate();
        emit MintFeeUpdated(oldFee, fee);
    }

    function setInstantRedeemFee(Bps fee) external restricted {
        Bps oldFee = _getStorage().instantRedeemFee;
        _getStorage().instantRedeemFee = fee.validate();
        emit InstantRedeemFeeUpdated(oldFee, fee);
    }

    function setPerformanceFee(Bps fee) external restricted {
        Bps oldFee = _getStorage().performanceFee;
        _getStorage().performanceFee = fee.validate();
        emit PerformanceFeeUpdated(oldFee, fee);
    }

    function getFees() external view returns (address treasury, Bps mintFee, Bps instantRedeemFee, Bps performanceFee) {
        Storage storage $ = _getStorage();
        return ($.treasury, $.mintFee, $.instantRedeemFee, $.performanceFee);
    }

    function getRedeem(uint256 redeemId) external view returns (RedeemData memory) {
        return _getStorage().redeems[redeemId];
    }

    function _checkIfUnderlyingAvailable(uint256 underlyingAmount) internal view returns (uint256) {
        Storage storage $ = _getStorage();

        uint256 underlyingBalance = underlying.balanceOf(address(this));
        uint256 lockedAssets = $.redeems[$.lastRedeemId].cumAssetAmount - $.processedRedeems;
        require(
            underlyingBalance.asAssetAmount(_scale) - lockedAssets >= underlyingAmount.asAssetAmount(_scale),
            NoAvailableUnderlyingAmount()
        );
    }

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
