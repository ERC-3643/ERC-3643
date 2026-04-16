// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import { ERC3643EventsLib } from "contracts/ERC-3643/ERC3643EventsLib.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ErrorsLib } from "contracts/libraries/ErrorsLib.sol";
import { RolesLib } from "contracts/libraries/RolesLib.sol";
import { IIdentityRegistry } from "contracts/registry/interface/IIdentityRegistry.sol";

import { TokenBaseUnitTest } from "../helpers/TokenBaseUnitTest.t.sol";

contract TokenRecoveryUnitTest is TokenBaseUnitTest {

    address lostWallet = makeAddr("LostWallet");
    address newWallet = makeAddr("NewWallet");
    address investorOnchainId = makeAddr("InvestorOnchainId");
    uint256 mintAmount = 1000;
    uint256 frozenAmount = 300;

    function setUp() public override {
        super.setUp();

        vm.startPrank(agent);
        token.unpause();
        token.mint(lostWallet, mintAmount);
        vm.stopPrank();
    }

    function testTokenRecoveryAddressRevertsWhenNotAgent(address caller) public {
        vm.assume(caller != agent);

        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        vm.prank(caller);
        token.recoveryAddress(lostWallet, newWallet, investorOnchainId);
    }

    function testTokenRecoveryAddressRevertsWhenNoTokenToRecover() public {
        address emptyWallet = makeAddr("EmptyWallet");

        vm.expectRevert(ErrorsLib.NoTokenToRecover.selector);
        vm.prank(agent);
        token.recoveryAddress(emptyWallet, newWallet, investorOnchainId);
    }

    function testTokenRecoveryAddressRevertsWhenRecoveryNotPossible() public {
        address unregisteredWallet = makeAddr("UnregisteredWallet");

        mockIdentityRegistryContains(lostWallet, false);
        mockIdentityRegistryContains(unregisteredWallet, false);

        vm.expectRevert(ErrorsLib.RecoveryNotPossible.selector);
        vm.prank(agent);
        token.recoveryAddress(lostWallet, unregisteredWallet, investorOnchainId);
    }

    function testTokenRecoveryAddressNominal() public {
        mockIdentityRegistryContains(lostWallet, true);
        mockIdentityRegistryContains(newWallet, false);
        mockIdentityRegistryIsLocallyRegistered(lostWallet, true);
        mockIdentityRegistryIsLocallyRegistered(newWallet, false);
        mockIdentityRegistryRegisterIdentity(newWallet, IIdentity(investorOnchainId), 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.RecoverySuccess(lostWallet, newWallet, investorOnchainId);
        vm.prank(agent);
        bool success = token.recoveryAddress(lostWallet, newWallet, investorOnchainId);

        assertTrue(success);
        assertEq(token.balanceOf(lostWallet), 0);
        assertEq(token.balanceOf(newWallet), mintAmount);
    }

    function testTokenRecoveryAddressTransfersFrozenTokens() public {
        // Freeze some tokens
        vm.prank(agent);
        token.freezePartialTokens(lostWallet, frozenAmount);

        mockIdentityRegistryContains(lostWallet, true);
        mockIdentityRegistryContains(newWallet, false);
        mockIdentityRegistryIsLocallyRegistered(lostWallet, true);
        mockIdentityRegistryIsLocallyRegistered(newWallet, false);
        mockIdentityRegistryRegisterIdentity(newWallet, IIdentity(investorOnchainId), 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.TokensUnfrozen(lostWallet, frozenAmount);
        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.TokensFrozen(newWallet, frozenAmount);
        vm.prank(agent);
        token.recoveryAddress(lostWallet, newWallet, investorOnchainId);

        assertEq(token.getFrozenTokens(lostWallet), 0);
        assertEq(token.getFrozenTokens(newWallet), frozenAmount);
    }

    function testTokenRecoveryAddressTransfersAddressFreeze() public {
        // Freeze the address
        vm.prank(agent);
        token.setAddressFrozen(lostWallet, true);

        mockIdentityRegistryContains(lostWallet, true);
        mockIdentityRegistryContains(newWallet, false);
        mockIdentityRegistryIsLocallyRegistered(lostWallet, true);
        mockIdentityRegistryIsLocallyRegistered(newWallet, false);
        mockIdentityRegistryRegisterIdentity(newWallet, IIdentity(investorOnchainId), 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.AddressFrozen(lostWallet, false, address(token));
        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.AddressFrozen(newWallet, true, address(token));
        vm.prank(agent);
        token.recoveryAddress(lostWallet, newWallet, investorOnchainId);

        assertFalse(token.isFrozen(lostWallet));
        assertTrue(token.isFrozen(newWallet));
    }

    function testTokenRecoveryAddressWhenNewWalletAlreadyRegistered() public {
        // Mock identity registry contains - both wallets are registered
        mockIdentityRegistryContains(lostWallet, true);
        mockIdentityRegistryContains(newWallet, true);
        mockIdentityRegistryIsLocallyRegistered(lostWallet, true);
        mockIdentityRegistryIsLocallyRegistered(newWallet, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit ERC3643EventsLib.RecoverySuccess(lostWallet, newWallet, investorOnchainId);
        vm.prank(agent);
        token.recoveryAddress(lostWallet, newWallet, investorOnchainId);

        assertEq(token.balanceOf(lostWallet), 0);
        assertEq(token.balanceOf(newWallet), mintAmount);
    }

    function testTokenRecoveryAddressRevertsWhenDisableRecoveryRestrictionIsSet() public {
        vm.prank(accessManagerAdmin);
        accessManager.revokeRole(RolesLib.AGENT_RECOVERY_ADDRESS, agent);

        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, agent));
        vm.prank(agent);
        token.recoveryAddress(lostWallet, newWallet, investorOnchainId);
    }

    /// ----- Helpers ------

    function mockIdentityRegistryContains(address wallet, bool contains) internal {
        vm.mockCall(
            identityRegistry,
            abi.encodeWithSelector(IERC3643IdentityRegistry.contains.selector, wallet),
            abi.encode(contains)
        );
    }

    function mockIdentityRegistryIsLocallyRegistered(address wallet, bool locallyRegistered) internal {
        vm.mockCall(
            identityRegistry,
            abi.encodeWithSelector(IIdentityRegistry.isLocallyRegistered.selector, wallet),
            abi.encode(locallyRegistered)
        );
    }

    function mockIdentityRegistryRegisterIdentity(address wallet, IIdentity identity, uint16 country) internal {
        vm.mockCall(
            identityRegistry,
            abi.encodeWithSelector(IERC3643IdentityRegistry.registerIdentity.selector, wallet, identity, country),
            ""
        );
    }

}

