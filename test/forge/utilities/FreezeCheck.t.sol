// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IdentityProxy } from "@onchain-id/solidity/contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { Token } from "contracts/token/Token.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { TREXFactorySetup } from "test/forge/helpers/TREXFactorySetup.sol";

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

        // Add tokenAgent as an agent to Token
        vm.prank(deployer);
        token.addAgent(tokenAgent);

        // Get IdentityRegistry to register identities
        IERC3643IdentityRegistry ir = token.identityRegistry();
        IdentityRegistry identityRegistry = IdentityRegistry(address(ir));

        // Add tokenAgent as an agent to IdentityRegistry
        vm.prank(deployer);
        identityRegistry.addAgent(tokenAgent);

        // Create identities for alice and bob
        ImplementationAuthority identityImplementationAuthority =
            ImplementationAuthority(onchainidSetup.idFactory.implementationAuthority());
        IIdentity aliceIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), alice)));
        IIdentity bobIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), bob)));

        // Register alice and bob in IdentityRegistry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);

        // Mint tokens to alice (alice gets 1000)
        vm.prank(tokenAgent);
        token.mint(alice, 1000);

        // Unpause token (tokens are paused by default)
        vm.prank(tokenAgent);
        token.unpause();

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
