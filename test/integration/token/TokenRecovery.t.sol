// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { ERC3643EventsLib } from "contracts/ERC-3643/ERC3643EventsLib.sol";
import { ErrorsLib } from "contracts/libraries/ErrorsLib.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";

import { TREXSuiteTest } from "../helpers/TREXSuiteTest.sol";

contract TokenRecoveryTest is TREXSuiteTest {

    IdentityRegistry public identityRegistry;

    function setUp() public override {
        super.setUp();

        identityRegistry = IdentityRegistry(address(token.identityRegistry()));

        vm.prank(agent);
        token.mint(bob, 500);

        vm.prank(agent);
        token.unpause();
    }

    // ============ recoveryAddress() Tests ============

    /// @notice Should revert when wallet to recover has no balance
    function test_recoveryAddress_RevertWhen_NoBalance() public {
        // Use agent to burn all bob's tokens
        uint256 bobBalance = token.balanceOf(bob);
        vm.prank(agent);
        token.burn(bob, bobBalance);

        vm.prank(agent);
        vm.expectRevert(ErrorsLib.NoTokenToRecover.selector);
        token.recoveryAddress(bob, another, address(bobIdentity));
    }

    /// @notice Should still recover when the lost wallet is no longer locally registered but is known
    /// globally through the IdFactory fallback — the global fallback makes the identity resolvable.
    function test_recoveryAddress_Success_WhenLostWalletOnlyGloballyRegistered() public {
        // Delete bob from the local identity registry. Bob still has a global identity.
        vm.prank(agent);
        identityRegistry.deleteIdentity(bob);

        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(identityRegistry.isLocallyRegistered(another));
        assertFalse(identityRegistry.isLocallyRegistered(bob));
    }

    /// @notice Should recover and freeze tokens on the new wallet when wallet has frozen token
    function test_recoveryAddress_Success_WithFrozenTokens() public {
        // Add key to bobIdentity for another address
        bytes32 keyHash = keccak256(abi.encode(another));
        vm.prank(bob);
        bobIdentity.addKey(keyHash, 1, 1);

        // Freeze partial tokens on bob
        vm.prank(agent);
        token.freezePartialTokens(bob, 50);

        vm.prank(agent);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.getFrozenTokens(another), 50);
    }

    /// @notice Should revert when identity registry does not contain the lost or new wallet
    /// @notice Should update the identity registry correctly when recovery is successful
    function test_recoveryAddress_Success_WithIdentityTransfer() public {
        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.isLocallyRegistered(bob));
        assertTrue(identityRegistry.isLocallyRegistered(another));
    }

    /// @notice Should only remove the lost wallet from the registry when new wallet is already in it
    function test_recoveryAddress_Success_NewWalletAlreadyInRegistry() public {
        // Register another in identity registry
        vm.prank(agent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.isLocallyRegistered(bob));
        assertTrue(identityRegistry.isLocallyRegistered(another));
    }

    /// @notice Should recover without touching IRS when recovery already happened on another token
    function test_recoveryAddress_Success_RecoveryAlreadyHappened() public {
        // Delete bob and register another (simulating recovery on another token)
        vm.prank(agent);
        identityRegistry.deleteIdentity(bob);
        vm.prank(agent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.isLocallyRegistered(bob));
        assertTrue(identityRegistry.isLocallyRegistered(another));
    }

    /// @notice Should transfer the frozen status and transfer frozen tokens when old wallet is frozen and new is not
    function test_recoveryAddress_Success_OldFrozenNewNotFrozen() public {
        // Freeze bob address and partial tokens
        vm.prank(agent);
        token.setAddressFrozen(bob, true);
        vm.prank(agent);
        token.freezePartialTokens(bob, 50);

        vm.prank(agent);
        vm.expectEmit(true, false, false, false, address(token));
        emit ERC3643EventsLib.TokensFrozen(another, 50);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
        assertEq(token.getFrozenTokens(another), 50);
    }

    /// @notice Should transfer frozen tokens and keep freeze status when both wallets are frozen
    function test_recoveryAddress_Success_BothFrozen() public {
        // Freeze both addresses and partial tokens on bob
        vm.prank(agent);
        token.setAddressFrozen(bob, true);
        vm.prank(agent);
        token.setAddressFrozen(another, true);
        vm.prank(agent);
        token.freezePartialTokens(bob, 30);

        vm.prank(agent);
        vm.expectEmit(true, false, false, false, address(token));
        emit ERC3643EventsLib.TokensFrozen(another, 30);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
        assertEq(token.getFrozenTokens(another), 30);
    }

    /// @notice Should recover tokens without freezing any when there are no frozen tokens
    function test_recoveryAddress_Success_NoFrozenTokens() public {
        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.getFrozenTokens(another), 0);
    }

    /// @notice Should not emit AddressFrozen when new wallet is already frozen
    function test_recoveryAddress_Success_NewWalletAlreadyFrozen() public {
        // Freeze old wallet and new wallet
        vm.prank(agent);
        token.setAddressFrozen(bob, true);
        vm.prank(agent);
        token.setAddressFrozen(another, true);

        // Recovery should not emit AddressFrozen for new wallet since it's already frozen
        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.AddressFrozen(bob, false, address(token));
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
    }

    /// @notice Should recover when only new wallet is in registry (not lost wallet)
    function test_recoveryAddress_Success_OnlyNewWalletInRegistry() public {
        // Delete bob from identity registry but keep another registered
        vm.prank(agent);
        identityRegistry.deleteIdentity(bob);

        // Register another in identity registry
        vm.prank(agent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        // Recovery should work because new wallet is in registry
        vm.prank(agent);
        vm.expectEmit(true, true, true, false, address(token));
        emit ERC3643EventsLib.RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.balanceOf(another), 500);
        assertTrue(identityRegistry.isLocallyRegistered(another));
    }

}
