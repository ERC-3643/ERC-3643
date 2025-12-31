// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    ClaimTopicsRegistrySet,
    IdentityStorageSet,
    IdentityUpdated,
    TrustedIssuersRegistrySet
} from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ClaimIssuerTrick } from "contracts/_testContracts/ClaimIssuerTrick.sol";
import { MockContract } from "contracts/_testContracts/MockContract.sol";
import { InitializationFailed } from "contracts/errors/CommonErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { CallerDoesNotHaveAgentRole } from "contracts/errors/RoleErrors.sol";
import { ClaimTopicsRegistryProxy } from "contracts/proxy/ClaimTopicsRegistryProxy.sol";
import { IdentityRegistryProxy } from "contracts/proxy/IdentityRegistryProxy.sol";
import { IdentityRegistryStorageProxy } from "contracts/proxy/IdentityRegistryStorageProxy.sol";
import { TrustedIssuersRegistryProxy } from "contracts/proxy/TrustedIssuersRegistryProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { ClaimTopicsRegistry } from "contracts/registry/implementation/ClaimTopicsRegistry.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import {
    EligibilityChecksDisabledAlready,
    EligibilityChecksEnabledAlready
} from "contracts/registry/implementation/IdentityRegistry.sol";
import { IdentityRegistryStorage } from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import {
    EligibilityChecksDisabled,
    EligibilityChecksEnabled
} from "contracts/registry/interface/IIdentityRegistry.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { Test } from "forge-std/Test.sol";
import { IdentityFactoryHelper } from "test/helpers/IdentityFactoryHelper.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";

contract IdentityRegistryTest is Test {

    // Contracts
    IdentityRegistry public identityRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    IdentityRegistryStorage public identityRegistryStorage;
    TREXImplementationAuthority public implementationAuthority;
    ClaimIssuer public claimIssuerContract;

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public tokenAgent = makeAddr("tokenAgent");
    address public another = makeAddr("another");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Identity contracts
    IIdentity public aliceIdentity;
    IIdentity public bobIdentity;
    IIdentity public charlieIdentity;

    /// @notice Sets up IdentityRegistry via proxy with full suite
    function setUp() public {
        // Deploy TREX Implementation Authority with all implementations
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory implementationAuthoritySetup =
            ImplementationAuthorityHelper.deploy(true);
        implementationAuthority = implementationAuthoritySetup.implementationAuthority;

        // Transfer ownership to deployer
        Ownable(address(implementationAuthority)).transferOwnership(deployer);

        // Deploy ClaimTopicsRegistry
        ClaimTopicsRegistryProxy claimTopicsRegistryProxy =
            new ClaimTopicsRegistryProxy(address(implementationAuthority));
        claimTopicsRegistry = ClaimTopicsRegistry(address(claimTopicsRegistryProxy));
        claimTopicsRegistry.transferOwnership(deployer);

        // Deploy TrustedIssuersRegistry
        TrustedIssuersRegistryProxy trustedIssuersRegistryProxy =
            new TrustedIssuersRegistryProxy(address(implementationAuthority));
        trustedIssuersRegistry = TrustedIssuersRegistry(address(trustedIssuersRegistryProxy));
        trustedIssuersRegistry.transferOwnership(deployer);

        // Deploy IdentityRegistryStorage
        IdentityRegistryStorageProxy identityRegistryStorageProxy =
            new IdentityRegistryStorageProxy(address(implementationAuthority));
        identityRegistryStorage = IdentityRegistryStorage(address(identityRegistryStorageProxy));
        identityRegistryStorage.transferOwnership(deployer);

        // Deploy IdentityRegistry
        IdentityRegistryProxy identityRegistryProxy = new IdentityRegistryProxy(
            address(implementationAuthority),
            address(trustedIssuersRegistry),
            address(claimTopicsRegistry),
            address(identityRegistryStorage)
        );
        identityRegistry = IdentityRegistry(address(identityRegistryProxy));
        identityRegistry.transferOwnership(deployer);

        // Bind identityRegistry to identityRegistryStorage
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        // Deploy ONCHAINID infrastructure for Identity proxies
        IdentityFactoryHelper.ONCHAINIDSetup memory onchainidSetup = IdentityFactoryHelper.deploy(deployer);

        // Transfer IdFactory ownership to deployer (it's initially owned by test contract)
        Ownable(address(onchainidSetup.idFactory)).transferOwnership(deployer);

        // create identities using IdFactory
        vm.startPrank(deployer);
        aliceIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(alice, "alice-salt"));
        bobIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(bob, "bob-salt"));
        charlieIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(charlie, "charlie-salt"));
        vm.stopPrank();

        // Add claim topic and trusted issuer
        uint256 claimTopic = 1;
        vm.prank(deployer);
        claimTopicsRegistry.addClaimTopic(claimTopic);

        claimIssuerContract = new ClaimIssuer(charlie);
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = claimTopic;
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(claimIssuerContract, claimTopics);

        // Register identities (alice and bob are registered)
        {
            vm.prank(deployer);
            identityRegistry.addAgent(tokenAgent);

            address[] memory userAddresses = new address[](2);
            userAddresses[0] = alice;
            userAddresses[1] = bob;

            IIdentity[] memory identities = new IIdentity[](2);
            identities[0] = aliceIdentity;
            identities[1] = bobIdentity;

            uint16[] memory countries = new uint16[](2);
            countries[0] = 42;
            countries[1] = 666;

            vm.prank(tokenAgent);
            identityRegistry.batchRegisterIdentity(userAddresses, identities, countries);
        }

        // Add signing key to ClaimIssuer and create claims for alice and bob
        uint256 claimIssuerSigningKeyPrivateKey = 0x12345; // Private key for signing
        address claimIssuerSigningKeyAddress = vm.addr(claimIssuerSigningKeyPrivateKey);

        // Add signing key to ClaimIssuer (purpose 3 = CLAIM, keyType 1 = ECDSA)
        // The key is stored as keccak256(address), and purpose 3 means CLAIM_SIGNER
        bytes32 signingKeyHash = keccak256(abi.encode(claimIssuerSigningKeyAddress));
        vm.prank(charlie); // charlie is the ClaimIssuer owner
        claimIssuerContract.addKey(signingKeyHash, 3, 1);

        // Create claim data
        bytes memory claimData = "Some claim public data.";

        // Create and add claims for alice and bob
        _addClaim(
            aliceIdentity, claimTopic, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuerContract), alice
        );
        _addClaim(
            bobIdentity, claimTopic, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuerContract), bob
        );
    }

    /// @notice Helper function to create and add a claim to an identity
    /// @param _identity The identity contract to add the claim to
    /// @param _claimTopic The claim topic
    /// @param _claimData The claim data
    /// @param _signingKeyPrivateKey The private key used to sign the claim
    /// @param _claimIssuer The address of the claim issuer
    /// @param _userAddress The user address (used for prank when adding claim)
    function _addClaim(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes memory _claimData,
        uint256 _signingKeyPrivateKey,
        address _claimIssuer,
        address _userAddress
    ) internal {
        // Compute dataHash = keccak256(abi.encode(identity, topic, data))
        bytes32 dataHash = keccak256(abi.encode(address(_identity), _claimTopic, _claimData));
        // Compute prefixedHash for EIP-191 signing
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signingKeyPrivateKey, prefixedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.prank(_userAddress);
        _identity.addClaim(_claimTopic, 1, _claimIssuer, signature, _claimData, "");
    }

    // ============ init() Tests ============

    /// @notice Should prevent to initialize again
    function test_init_RevertWhen_AlreadyInitialized() public {
        vm.prank(deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        identityRegistry.init(address(0), address(0), address(0));
    }

    /// @notice Should reject zero address for all parameters when calling init directly
    function test_init_RevertWhen_ZeroAddress_InitCall() public {
        // Deploy new implementation
        IdentityRegistry implementation = new IdentityRegistry();

        vm.expectRevert(ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(0), // Zero address for Trusted Issuers Registry
                address(claimTopicsRegistry),
                address(identityRegistryStorage)
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(trustedIssuersRegistry),
                address(0), // Zero address for Claim Topics Registry
                address(identityRegistryStorage)
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                IdentityRegistry.init.selector,
                address(trustedIssuersRegistry),
                address(claimTopicsRegistry),
                address(0) // Zero address for Identity Storage
            )
        );
    }

    /// @notice Should reject zero address for Trusted Issuers Registry
    function test_init_RevertWhen_TrustedIssuersRegistryZeroAddress() public {
        // Deploy new implementation
        IdentityRegistry implementation = new IdentityRegistry();

        // Deploy proxy with zero address for Trusted Issuers Registry
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new IdentityRegistryProxy(address(implementationAuthority), randomAddress, address(0), randomAddress);
    }

    /// @notice Should reject zero address for Claim Topics Registry
    function test_init_RevertWhen_ClaimTopicsRegistryZeroAddress() public {
        // Deploy new implementation
        IdentityRegistry implementation = new IdentityRegistry();

        // Deploy proxy with zero address for Claim Topics Registry
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new IdentityRegistryProxy(address(implementationAuthority), randomAddress, randomAddress, address(0));
    }

    /// @notice Should reject zero address for Identity Storage
    function test_init_RevertWhen_IdentityStorageZeroAddress() public {
        // Deploy new implementation
        IdentityRegistry implementation = new IdentityRegistry();

        // Deploy proxy with zero address for Identity Storage
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new IdentityRegistryProxy(address(implementationAuthority), address(0), randomAddress, randomAddress);
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid IR implementation
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));

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

        // Add version to IA (need to be owner)
        Ownable(address(incompleteIA)).transferOwnership(deployer);
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        address randomAddress = vm.addr(999);
        vm.expectRevert(InitializationFailed.selector);
        new IdentityRegistryProxy(address(incompleteIA), randomAddress, randomAddress, randomAddress);
    }

    // ============ updateIdentity() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_updateIdentity_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistry.updateIdentity(bob, charlieIdentity);
    }

    /// @notice Should update identity successfully when called by agent
    function test_updateIdentity_Success() public {
        // Get bob's current identity
        IIdentity oldIdentity = identityRegistry.identity(bob);
        assertEq(address(oldIdentity), address(bobIdentity));

        // Update to charlie's identity
        vm.expectEmit(true, true, false, false, address(identityRegistry));
        emit IdentityUpdated(oldIdentity, charlieIdentity);
        vm.prank(tokenAgent);
        identityRegistry.updateIdentity(bob, charlieIdentity);

        // Verify identity was updated
        IIdentity newIdentity = identityRegistry.identity(bob);
        assertEq(address(newIdentity), address(charlieIdentity));
    }

    // ============ updateCountry() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_updateCountry_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistry.updateCountry(bob, 100);
    }

    // ============ deleteIdentity() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_deleteIdentity_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistry.deleteIdentity(bob);
    }

    // ============ registerIdentity() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_registerIdentity_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistry.registerIdentity(address(0), IIdentity(address(0)), 0);
    }

    // ============ setIdentityRegistryStorage() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setIdentityRegistryStorage_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistry.setIdentityRegistryStorage(address(0));
    }

    /// @notice Should set the identity registry storage
    function test_setIdentityRegistryStorage_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit IdentityStorageSet(address(0));
        identityRegistry.setIdentityRegistryStorage(address(0));

        assertEq(address(identityRegistry.identityStorage()), address(0));
    }

    // ============ setClaimTopicsRegistry() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setClaimTopicsRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistry.setClaimTopicsRegistry(address(0));
    }

    /// @notice Should set the claim topics registry
    function test_setClaimTopicsRegistry_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ClaimTopicsRegistrySet(address(0));
        identityRegistry.setClaimTopicsRegistry(address(0));

        assertEq(address(identityRegistry.topicsRegistry()), address(0));
    }

    // ============ setTrustedIssuersRegistry() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_setTrustedIssuersRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistry.setTrustedIssuersRegistry(address(0));
    }

    /// @notice Should set the trusted issuers registry
    function test_setTrustedIssuersRegistry_Success() public {
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit TrustedIssuersRegistrySet(address(0));
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
        // Register charlie
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(charlie, charlieIdentity, 0);

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
        (, uint256 scheme, address issuer, bytes memory sig, bytes memory data,) = aliceIdentity.getClaim(claimIds[0]);

        vm.prank(charlie); // charlie is ClaimIssuer owner
        claimIssuerContract.revokeClaimBySignature(sig);

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
        trustedIssuersRegistry.removeTrustedIssuer(claimIssuerContract);
        trustedIssuersRegistry.addTrustedIssuer(IClaimIssuer(address(trickyClaimIssuer)), topics);
        trustedIssuersRegistry.addTrustedIssuer(claimIssuerContract, topics);
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistry.disableEligibilityChecks();
    }

    /// @notice Should disable eligibility checks and allow all addresses to be verified
    function test_disableEligibilityChecks_Success() public {
        vm.prank(deployer);
        vm.expectEmit(false, false, false, false);
        emit EligibilityChecksDisabled();
        identityRegistry.disableEligibilityChecks();

        // Now any address should be verified
        assertTrue(identityRegistry.isVerified(charlie));
    }

    /// @notice Should revert when eligibility checks are already disabled
    function test_disableEligibilityChecks_RevertWhen_AlreadyDisabled() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();

        vm.prank(deployer);
        vm.expectRevert(EligibilityChecksDisabledAlready.selector);
        identityRegistry.disableEligibilityChecks();
    }

    // ============ enableEligibilityChecks() Tests ============

    /// @notice Should revert when called by a non-owner
    function test_enableEligibilityChecks_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistry.enableEligibilityChecks();
    }

    /// @notice Should re-enable eligibility checks and enforce normal verification
    function test_enableEligibilityChecks_Success() public {
        vm.prank(deployer);
        identityRegistry.disableEligibilityChecks();
        assertTrue(identityRegistry.isVerified(another)); // another should be verified when disabled

        vm.prank(deployer);
        vm.expectEmit(false, false, false, false);
        emit EligibilityChecksEnabled();
        identityRegistry.enableEligibilityChecks();

        // Now another should not be verified (no identity registered)
        assertFalse(identityRegistry.isVerified(another));
    }

    /// @notice Should revert when eligibility checks are already enabled
    function test_enableEligibilityChecks_RevertWhen_AlreadyEnabled() public {
        vm.prank(deployer);
        vm.expectRevert(EligibilityChecksEnabledAlready.selector);
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

}
