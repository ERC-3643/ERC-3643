// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { KeyPurposes } from "@onchain-id/solidity/contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "@onchain-id/solidity/contracts/libraries/KeyTypes.sol";

import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";

import { Countries } from "../helpers/Countries.sol";
import { TREXSuiteTest } from "../helpers/TREXSuiteTest.sol";
import { TestModule } from "../mocks/TestModule.sol";

contract TransferCheckTest is TREXSuiteTest {

    UtilityChecker public utilityChecker;
    ModularCompliance public compliance;
    IdentityRegistry public identityRegistry;
    TestModule public testModule;

    function setUp() public override {
        super.setUp();

        token = _deployTokenWithClaimTopic("salt2", "Dino Token", "DINO");

        testModule =
            TestModule(address(new ModuleProxy(address(new TestModule()), abi.encodeCall(TestModule.initialize, ()))));
        compliance = ModularCompliance(address(token.compliance()));
        vm.prank(deployer);
        compliance.addModule(address(testModule));

        // Get IdentityRegistry
        identityRegistry = IdentityRegistry(address(token.identityRegistry()));

        // Register alice and bob in IdentityRegistry
        vm.prank(agent);
        identityRegistry.registerIdentity(alice, aliceIdentity, Countries.FRANCE);
        vm.prank(agent);
        identityRegistry.registerIdentity(bob, bobIdentity, Countries.SPAIN);

        // Set up claim issuer signing key and add claims for alice and bob
        uint256 claimIssuerSigningKeyPrivateKey = 0x12345;
        address claimIssuerSigningKeyAddress = vm.addr(claimIssuerSigningKeyPrivateKey);
        bytes32 signingKeyHash = keccak256(abi.encode(claimIssuerSigningKeyAddress));
        vm.prank(claimIssuerSigner.addr);
        claimIssuer.addKey(signingKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Add claims to alice and bob's identities
        bytes memory claimData = "Some claim public data.";
        _addClaim(aliceIdentity, CLAIM_TOPIC_1, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuer), alice);
        _addClaim(bobIdentity, CLAIM_TOPIC_1, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuer), bob);

        vm.startPrank(agent);
        token.mint(alice, 1000);
        token.mint(bob, 500);

        token.unpause();
        vm.stopPrank();

        // Deploy UtilityChecker
        utilityChecker = new UtilityChecker();
        utilityChecker.initialize();
    }

    // ============ getTransferStatus() Tests ============

    /// @notice Should return false when sender is frozen
    function test_getTransferStatus_ReturnsFalse_WhenSenderIsFrozen() public {
        vm.prank(agent);
        token.setAddressFrozen(alice, true);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when recipient is frozen
    function test_getTransferStatus_ReturnsFalse_WhenRecipientIsFrozen() public {
        vm.prank(agent);
        token.setAddressFrozen(bob, true);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when unfrozen balance is insufficient
    function test_getTransferStatus_ReturnsFalse_WhenUnfrozenBalanceInsufficient() public {
        uint256 initialBalance = token.balanceOf(alice);
        vm.prank(agent);
        token.freezePartialTokens(alice, initialBalance - 10);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return true in nominal case
    function test_getTransferStatus_ReturnsTrue_WhenNominalCase() public {
        // Update bob's country to ensure eligibility
        _addCountryClaim(bobIdentity, Countries.UNITED_STATES, bob);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when no identity is registered
    function test_getTransferStatus_ReturnsFalse_WhenNoIdentityRegistered() public view {
        // `another` has no identity registered locally AND no identity in the global IdFactory fallback,
        // so eligibility must fail regardless of the fallback semantics.
        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, another, 100);

        assertTrue(freezeStatus);
        assertFalse(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when identity is registered with topics but no claims
    function test_getTransferStatus_ReturnsFalse_WhenIdentityRegisteredWithTopics() public {
        // Register charlie (but no claims)
        vm.prank(agent);
        identityRegistry.registerIdentity(charlie, charlieIdentity, Countries.FRANCE);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, charlie, 100);

        assertTrue(freezeStatus);
        assertFalse(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return true after TREXFactorySetup
    function test_getTransferStatus_ReturnsTrue_AfterSetup() public {
        // Update bob's country to ensure eligibility
        _addCountryClaim(bobIdentity, Countries.UNITED_STATES, bob);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when token is paused
    function test_getTransferStatus_ReturnsFalse_WhenTokenPaused() public {
        // Pause the token
        vm.prank(agent);
        token.pause();

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when compliance check fails
    function test_getTransferStatus_ReturnsFalse_WhenComplianceCheckFails() public {
        vm.prank(address(compliance));
        testModule.blockModule(true);

        // Update bob's country to ensure eligibility
        _addCountryClaim(bobIdentity, Countries.UNITED_STATES, bob);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus, "freezeStatus");
        assertTrue(eligibilityStatus, "eligibilityStatus");
        assertFalse(complianceStatus, "complianceStatus");
    }

    /// @notice Should return true when all checks pass including compliance
    function test_getTransferStatus_ReturnsTrue_WhenAllChecksPass() public {
        // Update bob's country to ensure eligibility
        _addCountryClaim(bobIdentity, Countries.UNITED_STATES, bob);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus); // Should be true when all modules pass
    }

}
