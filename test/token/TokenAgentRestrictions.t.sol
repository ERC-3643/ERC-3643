// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IToken } from "contracts/token/IToken.sol";
import { AgentRestrictionsSet } from "contracts/token/IToken.sol";
import { AddressNotAgent } from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { TokenTestBase } from "test/token/TokenTestBase.sol";

contract TokenAgentRestrictionsTest is TokenTestBase {

    function setUp() public override {
        super.setUp();

        // Add tokenAgent as an agent
        vm.prank(deployer);
        token.addAgent(tokenAgent);
    }

    // ============ setAgentRestrictions() Tests ============

    /// @notice Should revert when called by not owner
    function test_setAgentRestrictions_RevertWhen_NotOwner() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setAgentRestrictions(tokenAgent, restrictions);
    }

    /// @notice Should revert when the given address is not an agent
    function test_setAgentRestrictions_RevertWhen_AddressNotAgent() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAgent.selector, another));
        token.setAgentRestrictions(another, restrictions);
    }

    /// @notice Should set restrictions when the given address is an agent
    function test_setAgentRestrictions_Success() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit AgentRestrictionsSet(tokenAgent, true, true, true, true, true, true, true);
        token.setAgentRestrictions(tokenAgent, restrictions); // agent already added in the setup above
    }

    // ============ getAgentRestrictions() Tests ============

    /// @notice Should return restrictions after they are set
    function test_getAgentRestrictions_ReturnsRestrictions() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        // Set restrictions
        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        // Get restrictions
        TokenRoles memory retrieved = token.getAgentRestrictions(tokenAgent);

        // Verify all restrictions are set correctly
        assertTrue(retrieved.disableAddressFreeze, "disableAddressFreeze should be true");
        assertTrue(retrieved.disableBurn, "disableBurn should be true");
        assertTrue(retrieved.disableForceTransfer, "disableForceTransfer should be true");
        assertTrue(retrieved.disableMint, "disableMint should be true");
        assertTrue(retrieved.disablePartialFreeze, "disablePartialFreeze should be true");
        assertTrue(retrieved.disablePause, "disablePause should be true");
        assertTrue(retrieved.disableRecovery, "disableRecovery should be true");
    }

}
