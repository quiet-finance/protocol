// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityNode} from "./base/LiquidityNode.sol";
import {BpsMath} from "./libraries/BpsMath.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";

struct RedeemRequest {
    address requester;
    uint256 amount;
    bool isProcessed;
}

contract LiquidityHubNode is LiquidityNode {
    using BpsMath for uint256;

    IqUSD immutable qUSD;
    IERC20 immutable USDC;
    address treasury;

    uint256 instantRedeemFeeBps;
    uint256 nextRedeemId;
    uint256 maxRedeemableId;
    mapping(uint256 => RedeemRequest) public redeemRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IqUSD qUSD_, IERC20 USDC_) {
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

    function asset() public view override returns (IERC20) {
        return USDC;
    }
}
