// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library BpsMath {
    uint256 constant BPS = 10_000;

    function validateBps(uint256 bps) internal pure {
        require(bps <= BPS);
    }

    function bpsOf(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * bps) / BPS;
    }
}
