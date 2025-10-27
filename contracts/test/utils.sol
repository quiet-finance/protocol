// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "forge-std/src/Base.sol";

import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

// Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);

Vm constant vm = Vm(VM_ADDRESS);

library proxy {
    function deploy(
        address _logic,
        address initialOwner,
        bytes memory _data
    ) internal returns (address) {
        return
            address(
                new TransparentUpgradeableProxy(_logic, initialOwner, _data)
            );
    }
}

library accessManager {
    address constant ACCESS_MANAGER_OWNER =
        address(uint160(uint256(keccak256("access manager owner"))));

    function addr() internal pure returns (address) {
        return vm.computeCreateAddress(ACCESS_MANAGER_OWNER, 0);
    }

    function get() internal returns (AccessManager am) {
        vm.prank(address(ACCESS_MANAGER_OWNER));
        if (addr().code.length == 0) {
            am = new AccessManager(ACCESS_MANAGER_OWNER);
            vm.prank(address(ACCESS_MANAGER_OWNER));
        } else {
            return AccessManager(addr());
        }
    }

    function expectAccessManagedUnauthorized() internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessManaged.AccessManagedUnauthorized.selector,
                (address(this))
            )
        );
    }

    function grantAccess(
        address target,
        address account,
        bytes4 selector
    ) internal {
        uint64 ROLE = 1;
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;

        get().grantRole(ROLE, account, 0);
        get().setTargetFunctionRole(target, selectors, ROLE);
    }

    function grantAccess(address target, bytes4 selector) internal {
        grantAccess(target, address(this), selector);
    }
}
