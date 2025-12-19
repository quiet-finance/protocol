// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

type Bps is uint16;
using BpsMath for Bps global;

library BpsMath {
    Bps constant MAX = Bps.wrap(10_000);

    function validate(Bps bps) internal pure returns (Bps) {
        require(Bps.unwrap(bps) <= Bps.unwrap(MAX));
        return bps;
    }

    function portionOf(Bps bps, uint256 amount) internal pure returns (uint256) {
        return (amount * Bps.unwrap(bps)) / Bps.unwrap(MAX);
    }

    function splitOf(Bps bps, uint256 amount) internal pure returns (uint256 portion, uint256 remainder) {
        portion = portionOf(bps, amount);
        remainder = amount - portion;
    }
}
