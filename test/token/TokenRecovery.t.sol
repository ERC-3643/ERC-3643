// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AddressFrozen, RecoverySuccess, TokensFrozen } from "contracts/ERC-3643/IERC3643.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import {
    AgentNotAuthorized,
    CallerDoesNotHaveAgentRole,
    NoTokenToRecover,
    RecoveryNotPossible
} from "contracts/token/Token.sol";
import { Token } from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { TokenTestBase } from "test/token/TokenTestBase.sol";

contract TokenRecoveryTest is TokenTestBase {

    // Token suite components
    IdentityRegistry public identityRegistry;

    function setUp() public override {
        super.setUp();

        // Get IdentityRegistry
        IERC3643IdentityRegistry ir = token.identityRegistry();
        identityRegistry = IdentityRegistry(address(ir));

        // Add tokenAgent as an agent
        vm.prank(deployer);
        token.addAgent(tokenAgent);

        // Add tokenAgent as an agent to IdentityRegistry
        vm.prank(deployer);
        identityRegistry.addAgent(tokenAgent);

        // Register bob in IdentityRegistry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);

        // Mint tokens to bob
        vm.prank(tokenAgent);
        token.mint(bob, 500);

        // Unpause token
        vm.prank(tokenAgent);
        token.unpause();
    }

    // ============ recoveryAddress() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_recoveryAddress_RevertWhen_NotAgent() public {
        // Add key to bobIdentity for another address
        bytes32 keyHash = keccak256(abi.encode(another));
        vm.prank(bob);
        bobIdentity.addKey(keyHash, 1, 1);

        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.recoveryAddress(bob, another, address(bobIdentity));
    }

    /// @notice Should revert when agent permission is restricted
    function test_recoveryAddress_RevertWhen_AgentRestricted() public {
        // Add key to bobIdentity for another address
        bytes32 keyHash = keccak256(abi.encode(another));
        vm.prank(bob);
        bobIdentity.addKey(keyHash, 1, 1);

        // Set agent restrictions
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: true,
            disableForceTransfer: false,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "recovery disabled"));
        token.recoveryAddress(bob, another, address(bobIdentity));
    }

    /// @notice Should revert when wallet to recover has no balance
    function test_recoveryAddress_RevertWhen_NoBalance() public {
        // Use agent to burn all bob's tokens
        uint256 bobBalance = token.balanceOf(bob);
        vm.prank(tokenAgent);
        token.burn(bob, bobBalance);

        vm.prank(tokenAgent);
        vm.expectRevert(NoTokenToRecover.selector);
        token.recoveryAddress(bob, another, address(bobIdentity));
    }

    /// @notice Should recover and freeze tokens on the new wallet when wallet has frozen token
    function test_recoveryAddress_Success_WithFrozenTokens() public {
        // Add key to bobIdentity for another address
        bytes32 keyHash = keccak256(abi.encode(another));
        vm.prank(bob);
        bobIdentity.addKey(keyHash, 1, 1);

        // Freeze partial tokens on bob
        vm.prank(tokenAgent);
        token.freezePartialTokens(bob, 50);

        vm.prank(tokenAgent);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.getFrozenTokens(another), 50);
    }

    /// @notice Should revert when identity registry does not contain the lost or new wallet
    function test_recoveryAddress_RevertWhen_IdentityNotInRegistry() public {
        // Delete bob from identity registry
        vm.prank(tokenAgent);
        identityRegistry.deleteIdentity(bob);

        vm.prank(tokenAgent);
        vm.expectRevert(RecoveryNotPossible.selector);
        token.recoveryAddress(bob, another, address(bobIdentity));
    }

    /// @notice Should update the identity registry correctly when recovery is successful
    function test_recoveryAddress_Success_WithIdentityTransfer() public {
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.contains(bob));
        assertTrue(identityRegistry.contains(another));
    }

    /// @notice Should only remove the lost wallet from the registry when new wallet is already in it
    function test_recoveryAddress_Success_NewWalletAlreadyInRegistry() public {
        // Register another in identity registry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.contains(bob));
        assertTrue(identityRegistry.contains(another));
    }

    /// @notice Should recover without touching IRS when recovery already happened on another token
    function test_recoveryAddress_Success_RecoveryAlreadyHappened() public {
        // Delete bob and register another (simulating recovery on another token)
        vm.prank(tokenAgent);
        identityRegistry.deleteIdentity(bob);
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertFalse(identityRegistry.contains(bob));
        assertTrue(identityRegistry.contains(another));
    }

    /// @notice Should transfer the frozen status and transfer frozen tokens when old wallet is frozen and new is not
    function test_recoveryAddress_Success_OldFrozenNewNotFrozen() public {
        // Freeze bob address and partial tokens
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);
        vm.prank(tokenAgent);
        token.freezePartialTokens(bob, 50);

        vm.prank(tokenAgent);
        vm.expectEmit(true, false, false, false, address(token));
        emit TokensFrozen(another, 50);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
        assertEq(token.getFrozenTokens(another), 50);
    }

    /// @notice Should transfer frozen tokens and keep freeze status when both wallets are frozen
    function test_recoveryAddress_Success_BothFrozen() public {
        // Freeze both addresses and partial tokens on bob
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);
        vm.prank(tokenAgent);
        token.setAddressFrozen(another, true);
        vm.prank(tokenAgent);
        token.freezePartialTokens(bob, 30);

        vm.prank(tokenAgent);
        vm.expectEmit(true, false, false, false, address(token));
        emit TokensFrozen(another, 30);
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
        assertEq(token.getFrozenTokens(another), 30);
    }

    /// @notice Should recover tokens without freezing any when there are no frozen tokens
    function test_recoveryAddress_Success_NoFrozenTokens() public {
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.getFrozenTokens(another), 0);
    }

    /// @notice Should not emit AddressFrozen when new wallet is already frozen
    function test_recoveryAddress_Success_NewWalletAlreadyFrozen() public {
        // Freeze old wallet and new wallet
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);
        vm.prank(tokenAgent);
        token.setAddressFrozen(another, true);

        // Recovery should not emit AddressFrozen for new wallet since it's already frozen
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit AddressFrozen(bob, false, address(token));
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertTrue(token.isFrozen(another));
    }

    /// @notice Should recover when only new wallet is in registry (not lost wallet)
    function test_recoveryAddress_Success_OnlyNewWalletInRegistry() public {
        // Delete bob from identity registry but keep another registered
        vm.prank(tokenAgent);
        identityRegistry.deleteIdentity(bob);

        // Register another in identity registry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(another, bobIdentity, 1);

        // Recovery should work because new wallet is in registry
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit RecoverySuccess(bob, another, address(bobIdentity));
        token.recoveryAddress(bob, another, address(bobIdentity));

        assertEq(token.balanceOf(another), 500);
        assertTrue(identityRegistry.contains(another));
    }

}
