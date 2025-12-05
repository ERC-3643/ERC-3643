// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { AccountAlreadyHasRole, AccountDoesNotHaveRole } from "contracts/errors/RoleErrors.sol";
import { AgentRole } from "contracts/roles/AgentRole.sol";
import { Test } from "forge-std/Test.sol";

contract AgentRoleTest is Test {

    // Event declarations for expectEmit
    event AgentAdded(address indexed _agent);
    event AgentRemoved(address indexed _agent);

    // Contracts
    AgentRole public agentRole;

    // Standard test addresses
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /// @notice Sets up AgentRole contract
    function setUp() public {
        // Deploy AgentRole - owner will be the test contract (msg.sender)
        agentRole = new AgentRole();
        // Transfer ownership to owner address for consistency with Hardhat tests
        agentRole.transferOwnership(owner);
    }

    // ============ addAgent() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_addAgent_RevertWhen_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        agentRole.addAgent(alice);
    }

    /// @notice Should revert when address to add is zero address
    function test_addAgent_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        agentRole.addAgent(address(0));
    }

    /// @notice Should revert when address to add is already an agent
    function test_addAgent_RevertWhen_AlreadyAgent() public {
        vm.prank(owner);
        agentRole.addAgent(alice);

        vm.prank(owner);
        vm.expectRevert(AccountAlreadyHasRole.selector);
        agentRole.addAgent(alice);
    }

    /// @notice Should add the agent successfully
    function test_addAgent_Success() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AgentAdded(alice);
        agentRole.addAgent(alice);

        assertTrue(agentRole.isAgent(alice), "Alice should be an agent");
    }

    // ============ removeAgent() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_removeAgent_RevertWhen_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        agentRole.removeAgent(alice);
    }

    /// @notice Should revert when address to remove is zero address
    function test_removeAgent_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        agentRole.removeAgent(address(0));
    }

    /// @notice Should revert when address to remove is not an agent
    function test_removeAgent_RevertWhen_NotAgent() public {
        vm.prank(owner);
        vm.expectRevert(AccountDoesNotHaveRole.selector);
        agentRole.removeAgent(alice);
    }

    /// @notice Should remove the agent successfully
    function test_removeAgent_Success() public {
        // First add the agent
        vm.prank(owner);
        agentRole.addAgent(alice);

        // Then remove it
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AgentRemoved(alice);
        agentRole.removeAgent(alice);

        assertFalse(agentRole.isAgent(alice), "Alice should not be an agent");
    }

}
