// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { UtilityCheckerProxy } from "contracts/utils/UtilityCheckerProxy.sol";
import { Test } from "forge-std/Test.sol";

contract UpgradeTest is Test {

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");

    // EIP-1967 implementation slot
    bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ============ upgradeToAndCall() Tests ============

    /// @notice Should revert when calling directly (not owner)
    function test_upgradeToAndCall_RevertWhen_NotOwner() public {
        // Deploy implementation
        UtilityChecker implementation = new UtilityChecker();

        // Deploy proxy with initialization data
        bytes memory initData = abi.encodeWithSelector(UtilityChecker.initialize.selector);
        UtilityCheckerProxy proxy = new UtilityCheckerProxy(address(implementation), initData);
        UtilityChecker utilityChecker = UtilityChecker(address(proxy));

        // Transfer ownership to deployer (proxy deployer is address(this))
        utilityChecker.transferOwnership(deployer);

        // Deploy new implementation
        UtilityChecker newImplementation = new UtilityChecker();

        // Alice tries to upgrade (not owner)
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        utilityChecker.upgradeToAndCall(address(newImplementation), "");
    }

    /// @notice Should upgrade proxy when calling with owner account
    function test_upgradeToAndCall_Success() public {
        // Deploy implementation
        UtilityChecker implementation = new UtilityChecker();

        // Deploy proxy with initialization data
        bytes memory initData = abi.encodeWithSelector(UtilityChecker.initialize.selector);
        UtilityCheckerProxy proxy = new UtilityCheckerProxy(address(implementation), initData);
        UtilityChecker utilityChecker = UtilityChecker(address(proxy));

        // Transfer ownership to deployer (proxy deployer is address(this))
        utilityChecker.transferOwnership(deployer);

        // Deploy new implementation
        UtilityChecker newImplementation = new UtilityChecker();

        // Owner upgrades
        vm.prank(deployer);
        utilityChecker.upgradeToAndCall(address(newImplementation), "");

        // Read the implementation address from the EIP-1967 implementation slot
        bytes32 slotValue = vm.load(address(proxy), IMPLEMENTATION_SLOT);

        // Convert storage value to address (address is stored in last 20 bytes)
        address actualImplementation = address(uint160(uint256(slotValue)));

        assertEq(actualImplementation, address(newImplementation));
    }

}
