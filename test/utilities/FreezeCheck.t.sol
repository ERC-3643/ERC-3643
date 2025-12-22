// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { Token } from "contracts/token/Token.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract FreezeCheckTest is TREXFactorySetup {

    UtilityChecker public utilityChecker;
    Token public token;
    address public tokenAgent = makeAddr("tokenAgent");

    function setUp() public override {
        super.setUp();

        // Deploy token suite
        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "TREX DINO",
            symbol: "TREXD",
            decimals: 0,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });
        ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
            claimTopics: new uint256[](0), issuers: new address[](0), issuerClaims: new uint256[][](0)
        });

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        token = Token(trexFactory.getToken("salt"));

        // Add tokenAgent as an agent to Token and IdentityRegistry
        IERC3643IdentityRegistry ir = token.identityRegistry();
        IdentityRegistry identityRegistry = IdentityRegistry(address(ir));
        vm.startPrank(deployer);
        token.addAgent(tokenAgent);
        identityRegistry.addAgent(tokenAgent);
        vm.stopPrank();

        // Register alice and bob in IdentityRegistry, mint tokens, and unpause
        vm.startPrank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);
        token.mint(alice, 1000);
        token.unpause();
        vm.stopPrank();

        // Deploy UtilityChecker
        utilityChecker = new UtilityChecker();
        utilityChecker.initialize();
    }

    // ============ getFreezeStatus() Tests ============

    /// @notice Should return true when sender is frozen
    function test_getFreezeStatus_ReturnsTrue_WhenSenderIsFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(alice, true);

        (bool success, uint256 balance) = utilityChecker.getFreezeStatus(address(token), alice, bob, 100);
        assertTrue(success);
        assertEq(balance, 0);
    }

    /// @notice Should return true when recipient is frozen
    function test_getFreezeStatus_ReturnsTrue_WhenRecipientIsFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);

        (bool success, uint256 balance) = utilityChecker.getFreezeStatus(address(token), alice, bob, 100);
        assertTrue(success);
        assertEq(balance, 0);
    }

    /// @notice Should return true when unfrozen balance is insufficient
    function test_getFreezeStatus_ReturnsTrue_WhenUnfrozenBalanceInsufficient() public {
        uint256 initialBalance = token.balanceOf(alice);
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, initialBalance - 10);

        (bool success, uint256 balance) = utilityChecker.getFreezeStatus(address(token), alice, bob, 100);
        assertTrue(success);
        assertEq(balance, 10);
    }

    /// @notice Should return false in normal case
    function test_getFreezeStatus_ReturnsFalse_WhenNormalCase() public {
        uint256 initialBalance = token.balanceOf(alice);

        (bool success, uint256 balance) = utilityChecker.getFreezeStatus(address(token), alice, bob, 100);
        assertFalse(success);
        assertEq(balance, initialBalance);
    }

}
