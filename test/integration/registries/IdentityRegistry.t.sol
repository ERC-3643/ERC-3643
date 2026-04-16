// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { KeyPurposes } from "@onchain-id/solidity/contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "@onchain-id/solidity/contracts/libraries/KeyTypes.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { ERC3643EventsLib } from "contracts/ERC-3643/ERC3643EventsLib.sol";
import { AccessManagerSetupLib } from "contracts/libraries/AccessManagerSetupLib.sol";
import { ErrorsLib } from "contracts/libraries/ErrorsLib.sol";
import { EventsLib } from "contracts/libraries/EventsLib.sol";
import { IdentityRegistryProxy } from "contracts/proxy/IdentityRegistryProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { ClaimTopicsRegistry } from "contracts/registry/implementation/ClaimTopicsRegistry.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { IdentityRegistryStorage } from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";

import { Countries } from "../helpers/Countries.sol";
import { TREXSuiteTest } from "../helpers/TREXSuiteTest.sol";
import { ClaimIssuerTrick } from "../mocks/ClaimIssuerTrick.sol";
import { MockContract } from "../mocks/MockContract.sol";

contract IdentityRegistryTest is TREXSuiteTest {

    // Contracts
    IdentityRegistry public identityRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    IdentityRegistryStorage public identityRegistryStorage;

    /// @notice Sets up IdentityRegistry via proxy with full suite
    function setUp() public override {
        super.setUp();

        token = _deployTokenWithClaimTopic("salt2", "Dino Token", "DINO");

        claimTopicsRegistry = ClaimTopicsRegistry(address(token.identityRegistry().topicsRegistry()));
        identityRegistry = IdentityRegistry(address(token.identityRegistry()));
        identityRegistryStorage = IdentityRegistryStorage(address(token.identityRegistry().identityStorage()));
        trustedIssuersRegistry = TrustedIssuersRegistry(address(token.identityRegistry().issuersRegistry()));

        _registerIdentities(token);

        bytes memory claimData = "Some claim public data.";
        _addClaim(aliceIdentity, CLAIM_TOPIC_1, claimData, claimIssuerSigner.key, address(claimIssuer), alice);
        _addClaim(bobIdentity, CLAIM_TOPIC_1, claimData, claimIssuerSigner.key, address(claimIssuer), bob);
    }

    // ============ init() Tests ============

    /// @notice Should prevent to initialize again
    function test_init_RevertWhen_AlreadyInitialized() public {
        vm.prank(deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        identityRegistry.init(address(0), address(0), address(0), address(accessManager));
    }

    /// @notice Should reject zero address for all parameters when calling init directly
    function test_init_RevertWhen_ZeroAddress_InitCall() public {
        // Deploy new implementation
        IdentityRegistry implementation = new IdentityRegistry();

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(0), // Zero address for Trusted Issuers Registry
                address(claimTopicsRegistry),
                address(identityRegistryStorage),
                address(accessManager)
            )
        );

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(trustedIssuersRegistry),
                address(0), // Zero address for Claim Topics Registry
                address(identityRegistryStorage),
                address(accessManager)
            )
        );

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(trustedIssuersRegistry),
                address(claimTopicsRegistry),
                address(0), // Zero address for Identity Storage
                address(accessManager)
            )
        );
    }

    /// @notice Should reject zero address for Trusted Issuers Registry
    function test_init_RevertWhen_TrustedIssuersRegistryZeroAddress() public {
        // Deploy proxy with zero address for Trusted Issuers Registry
        address randomAddress = vm.addr(999);
        vm.expectRevert(ErrorsLib.InitializationFailed.selector);
        new IdentityRegistryProxy(
            address(trexImplementationAuthority), randomAddress, address(0), randomAddress, address(accessManager)
        );
    }

    /// @notice Should reject zero address for Claim Topics Registry
    function test_init_RevertWhen_ClaimTopicsRegistryZeroAddress() public {
        // Deploy proxy with zero address for Claim Topics Registry
        address randomAddress = vm.addr(999);
        vm.expectRevert(ErrorsLib.InitializationFailed.selector);
        new IdentityRegistryProxy(
            address(trexImplementationAuthority), randomAddress, randomAddress, address(0), address(accessManager)
        );
    }

    /// @notice Should reject zero address for Identity Storage
    function test_init_RevertWhen_IdentityStorageZeroAddress() public {
        // Deploy proxy with zero address for Identity Storage
        address randomAddress = vm.addr(999);
        vm.expectRevert(ErrorsLib.InitializationFailed.selector);
        new IdentityRegistryProxy(
            address(trexImplementationAuthority), address(0), randomAddress, randomAddress, address(accessManager)
        );
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid IR implementation
        TREXImplementationAuthority incompleteIA =
            new TREXImplementationAuthority(true, address(0), address(0), address(accessManager));
        vm.prank(accessManagerAdmin);
        AccessManagerSetupLib.setupTREXImplementationAuthorityRoles(accessManager, address(incompleteIA));

        // Create a version with invalid IR implementation (mock contract without init())
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(mockImpl), // Invalid - doesn't have proper init
            ctrImplementation: address(mockImpl), // Invalid
            irImplementation: address(mockImpl), // Invalid - doesn't have init() function
            irsImplementation: address(mockImpl), // Invalid
            tirImplementation: address(mockImpl), // Invalid
            mcImplementation: address(mockImpl) // Invalid
        });

        // Add version to IA
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        address randomAddress = vm.addr(999);
        vm.expectRevert(ErrorsLib.InitializationFailed.selector);
        new IdentityRegistryProxy(
            address(incompleteIA), randomAddress, randomAddress, randomAddress, address(accessManager)
        );
    }

    // ============ updateIdentity() Tests ============

    /// @notice Should update identity successfully when called by agent
    function test_updateIdentity_Success() public {
        // Get bob's current identity
        IIdentity oldIdentity = identityRegistry.identity(bob);
        assertEq(address(oldIdentity), address(bobIdentity));

        // Update to charlie's identity
        vm.expectEmit(true, true, false, false, address(identityRegistry));
        emit ERC3643EventsLib.IdentityUpdated(oldIdentity, charlieIdentity);
        vm.prank(agent);
        identityRegistry.updateIdentity(bob, charlieIdentity);

        // Verify identity was updated
        IIdentity newIdentity = identityRegistry.identity(bob);
        assertEq(address(newIdentity), address(charlieIdentity));
    }

    // ============ setIdentityRegistryStorage() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setIdentityRegistryStorage_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        identityRegistry.setIdentityRegistryStorage(address(0));
    }

    /// @notice Should set the identity registry storage
    function test_setIdentityRegistryStorage_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ERC3643EventsLib.IdentityStorageSet(address(0));
        identityRegistry.setIdentityRegistryStorage(address(0));

        assertEq(address(identityRegistry.identityStorage()), address(0));
    }

    // ============ setClaimTopicsRegistry() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setClaimTopicsRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        identityRegistry.setClaimTopicsRegistry(address(0));
    }

    /// @notice Should set the claim topics registry
    function test_setClaimTopicsRegistry_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ERC3643EventsLib.ClaimTopicsRegistrySet(address(0));
        identityRegistry.setClaimTopicsRegistry(address(0));

        assertEq(address(identityRegistry.topicsRegistry()), address(0));
    }

    // ============ setTrustedIssuersRegistry() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setTrustedIssuersRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        identityRegistry.setTrustedIssuersRegistry(address(0));
    }

    /// @notice Should set the trusted issuers registry
    function test_setTrustedIssuersRegistry_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ERC3643EventsLib.TrustedIssuersRegistrySet(address(0));
        identityRegistry.setTrustedIssuersRegistry(address(0));

        assertEq(address(identityRegistry.issuersRegistry()), address(0));
    }

    // ============ supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(identityRegistry.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IIdentityRegistry interface ID
    function test_supportsInterface_ReturnsTrue_ForIIdentityRegistry() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIIdentityRegistryInterfaceId();
        assertTrue(identityRegistry.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC3643IdentityRegistry interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC3643IdentityRegistry() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC3643IdentityRegistryInterfaceId();
        assertTrue(identityRegistry.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(identityRegistry.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(identityRegistry.supportsInterface(interfaceId));
    }

    // ============ isVerified() Tests ============

    /// @notice Should return true when the identity is registered and there are no required claim topics
    function test_isVerified_ReturnsTrue_WhenNoClaimTopics() public {
        // Initially charlie is not verified (has claim topic requirement)
        assertFalse(identityRegistry.isVerified(charlie));

        // Remove all claim topics, Basically we just added claim topic = 1 in the setup function
        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        for (uint256 i = 0; i < topics.length; i++) {
            vm.prank(deployer);
            claimTopicsRegistry.removeClaimTopic(topics[i]);
        }

        // Now charlie should be verified
        assertTrue(identityRegistry.isVerified(charlie));
    }

    /// @notice Should return false when claim topics are required but there are no trusted issuers for them
    function test_isVerified_ReturnsFalse_WhenNoTrustedIssuersForClaimTopic() public {
        // Initially alice is verified (has claim and trusted issuer)
        assertTrue(identityRegistry.isVerified(alice));

        // Remove all trusted issuers for the claim topic
        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        IClaimIssuer[] memory trustedIssuers = trustedIssuersRegistry.getTrustedIssuersForClaimTopic(topics[0]);
        for (uint256 i = 0; i < trustedIssuers.length; i++) {
            vm.prank(deployer);
            trustedIssuersRegistry.removeTrustedIssuer(trustedIssuers[i]);
        }

        // Now alice should not be verified
        assertFalse(identityRegistry.isVerified(alice));
    }

    /// @notice Should return false when the only claim required was revoked
    function test_isVerified_ReturnsFalse_WhenClaimRevoked() public {
        // Initially alice is verified
        assertTrue(identityRegistry.isVerified(alice));

        // Get claim and revoke it
        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(topics[0]);

        // claimIds[0] is already issued by ClaimIssuer in the setup
        (,,, bytes memory sig,,) = aliceIdentity.getClaim(claimIds[0]);

        vm.prank(claimIssuerSigner.addr);
        claimIssuer.revokeClaimBySignature(sig);

        // Now alice should not be verified
        assertFalse(identityRegistry.isVerified(alice));
    }

    /// @notice Should return true if there is another valid claim when one claim issuer throws an error
    function test_isVerified_ReturnsTrue_WhenClaimIssuerThrowsErrorButAnotherValidClaimExists() public {
        // Deploy ClaimIssuerTrick (always throws error on isClaimValid)
        ClaimIssuerTrick trickyClaimIssuer = new ClaimIssuerTrick();

        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        uint256 topic = topics[0];

        // Remove existing trusted issuer and add both tricky and normal issuer
        vm.startPrank(deployer);
        trustedIssuersRegistry.removeTrustedIssuer(IClaimIssuer(address(claimIssuer)));
        trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(address(trickyClaimIssuer)), topics);
        trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(address(claimIssuer)), topics);
        vm.stopPrank();

        // Get alice's existing claim
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(topic);
        (, uint256 scheme, address issuer, bytes memory sig, bytes memory data, string memory uri) =
            aliceIdentity.getClaim(claimIds[0]);

        // Remove the existing claim and add both tricky and normal claims
        vm.startPrank(alice);
        aliceIdentity.removeClaim(claimIds[0]);
        // Add tricky claim (will throw error)
        aliceIdentity.addClaim(topic, 1, address(trickyClaimIssuer), "0x00", "0x00", "");
        // Add normal claim (will work)
        aliceIdentity.addClaim(topic, scheme, issuer, sig, data, uri);
        vm.stopPrank();

        // Should still be verified (normal claim works)
        assertTrue(identityRegistry.isVerified(alice));
    }

    /// @notice Should return false if there are no other valid claims when claim issuer throws an error
    function test_isVerified_ReturnsFalse_WhenClaimIssuerThrowsErrorAndNoOtherValidClaim() public {
        // Deploy ClaimIssuerTrick (always throws error on isClaimValid)
        ClaimIssuerTrick trickyClaimIssuer = new ClaimIssuerTrick();

        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        uint256 topic = topics[0];

        // Add tricky issuer as trusted
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(address(trickyClaimIssuer)), topics);

        // Get alice's existing claim and remove it
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(topic);
        vm.prank(alice);
        aliceIdentity.removeClaim(claimIds[0]);

        // Add only tricky claim (will throw error, no other valid claim)
        vm.prank(alice);
        aliceIdentity.addClaim(topic, 1, address(trickyClaimIssuer), "0x00", "0x00", "");

        // Should not be verified (only claim throws error)
        assertFalse(identityRegistry.isVerified(alice));
    }

    // ============ disableEligibilityChecks() Tests ============

    /// @notice Should revert when called by a non-owner
    function test_disableEligibilityChecks_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        identityRegistry.disableEligibilityChecks();
    }

    /// @notice Should disable eligibility checks and allow all addresses to be verified
    function test_disableEligibilityChecks_Success() public {
        vm.prank(deployer);
        vm.expectEmit(false, false, false, false);
        emit EventsLib.EligibilityChecksDisabled();
        identityRegistry.disableEligibilityChecks();

        // Now any address should be verified
        assertTrue(identityRegistry.isVerified(charlie));
    }

    /// @notice Should revert when eligibility checks are already disabled
    function test_disableEligibilityChecks_RevertWhen_AlreadyDisabled() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();

        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.EligibilityChecksDisabledAlready.selector);
        identityRegistry.disableEligibilityChecks();
    }

    // ============ enableEligibilityChecks() Tests ============

    /// @notice Should revert when called by a non-owner
    function test_enableEligibilityChecks_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        identityRegistry.enableEligibilityChecks();
    }

    /// @notice Should re-enable eligibility checks and enforce normal verification
    function test_enableEligibilityChecks_Success() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();
        assertTrue(identityRegistry.isVerified(another)); // another should be verified when disabled

        vm.prank(deployer);
        vm.expectEmit(false, false, false, false);
        emit EventsLib.EligibilityChecksEnabled();
        identityRegistry.enableEligibilityChecks();

        // Now another should not be verified (no identity registered)
        assertFalse(identityRegistry.isVerified(another));
    }

    /// @notice Should revert when eligibility checks are already enabled
    function test_enableEligibilityChecks_RevertWhen_AlreadyEnabled() public {
        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.EligibilityChecksEnabledAlready.selector);
        identityRegistry.enableEligibilityChecks();
    }

    // ============ isVerified() Tests (with eligibility checks) ============

    /// @notice Should return true for any address when eligibility checks are disabled
    function test_isVerified_ReturnsTrue_WhenEligibilityChecksDisabled() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();

        assertTrue(identityRegistry.isVerified(charlie));
    }

    /// @notice Should resume normal eligibility checks when re-enabled
    function test_isVerified_ResumesNormalChecks_WhenReEnabled() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();
        assertTrue(identityRegistry.isVerified(charlie));

        vm.prank(deployer);
        identityRegistry.enableEligibilityChecks();

        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        if (topics.length > 0) {
            // charlie is not registered and has claim topics, so should be false
            assertFalse(identityRegistry.isVerified(charlie));
        } else {
            // If no topics required, verification should pass
            assertTrue(identityRegistry.isVerified(charlie));
        }
    }

    // ============ investorCountry() Tests ============

    /// @notice Should return the country from the identity's country claim
    function test_investorCountry_ReturnsCountryFromClaim() public view {
        assertEq(identityRegistry.investorCountry(alice), Countries.FRANCE);
    }

    /// @notice Should return 0 when identity has no country claim
    function test_investorCountry_ReturnsZero_WhenNoCountryClaim() public view {
        assertEq(identityRegistry.investorCountry(another), 0);
    }

    // ============ updateCountry() Tests ============

    /// @notice Should revert with Deprecated
    function test_updateCountry_RevertWhen_Deprecated() public {
        vm.prank(accessManagerAdmin);
        vm.expectRevert(ErrorsLib.Deprecated.selector);
        identityRegistry.updateCountry(alice, Countries.SPAIN);
    }

}
