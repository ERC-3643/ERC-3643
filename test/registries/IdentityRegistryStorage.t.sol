// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    CountryModified,
    IdentityModified,
    IdentityRegistryBound,
    IdentityRegistryUnbound,
    IdentityStored,
    IdentityUnstored
} from "contracts/ERC-3643/IERC3643IdentityRegistryStorage.sol";
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
import { IdentityRegistryStorage } from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import {
    AddressAlreadyStored,
    AddressNotYetStored,
    IdentityRegistryNotStored,
    MaxIRByIRSReached
} from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { Test } from "forge-std/Test.sol";
import { IdentityFactoryHelper } from "test/helpers/IdentityFactoryHelper.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";

contract IdentityRegistryStorageTest is Test {

    // Contracts
    IdentityRegistryStorage public identityRegistryStorage;
    TREXImplementationAuthority public implementationAuthority;

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public tokenAgent = makeAddr("tokenAgent");
    address public another = makeAddr("another");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Identity contracts
    IIdentity public bobIdentity;
    IIdentity public charlieIdentity;

    /// @notice Sets up IdentityRegistryStorage via proxy
    function setUp() public {
        // Deploy TREX Implementation Authority with all implementations
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory implementationAuthoritySetup =
            ImplementationAuthorityHelper.deploy(true);
        implementationAuthority = implementationAuthoritySetup.implementationAuthority;

        // Transfer ownership to deployer
        Ownable(address(implementationAuthority)).transferOwnership(deployer);

        // Deploy IdentityRegistryStorageProxy (which initializes via delegatecall)
        IdentityRegistryStorageProxy proxy = new IdentityRegistryStorageProxy(address(implementationAuthority));
        identityRegistryStorage = IdentityRegistryStorage(address(proxy));

        // Transfer ownership to deployer (owner is initially the test contract)
        identityRegistryStorage.transferOwnership(deployer);

        // Deploy ONCHAINID infrastructure for Identity proxies
        IdentityFactoryHelper.ONCHAINIDSetup memory onchainidSetup = IdentityFactoryHelper.deploy(deployer);

        // Transfer IdFactory ownership to deployer (it's initially owned by test contract)
        Ownable(address(onchainidSetup.idFactory)).transferOwnership(deployer);

        // Create identities using IdFactory
        vm.startPrank(deployer);
        bobIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(bob, "bob-salt"));
        charlieIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(charlie, "charlie-salt"));
        vm.stopPrank();

        // Note: In Hardhat fixture, identityRegistry.target is bound to storage in setUp
        // For Foundry, we start with 0 bound registries (tests will bind as needed)
    }

    // ============ init() Tests ============

    /// @notice Should revert when contract was already initialized
    function test_init_RevertWhen_AlreadyInitialized() public {
        vm.prank(deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        identityRegistryStorage.init();
    }

    // ============ addIdentityToStorage() Tests ============

    /// @notice Should revert when sender is not agent
    function test_addIdentityToStorage_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistryStorage.addIdentityToStorage(charlie, charlieIdentity, 42);
    }

    /// @notice Should revert when identity is zero address
    function test_addIdentityToStorage_RevertWhen_IdentityZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.addIdentityToStorage(charlie, IIdentity(address(0)), 42);
    }

    /// @notice Should revert when wallet is zero address
    function test_addIdentityToStorage_RevertWhen_WalletZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.addIdentityToStorage(address(0), charlieIdentity, 42);
    }

    /// @notice Should revert when wallet is already registered
    function test_addIdentityToStorage_RevertWhen_AlreadyStored() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        // Add bob first
        vm.prank(tokenAgent);
        identityRegistryStorage.addIdentityToStorage(bob, bobIdentity, 42);

        // Try to add bob again
        vm.prank(tokenAgent);
        vm.expectRevert(AddressAlreadyStored.selector);
        identityRegistryStorage.addIdentityToStorage(bob, charlieIdentity, 666);
    }

    // ============ modifyStoredIdentity() Tests ============

    /// @notice Should revert when sender is not agent
    function test_modifyStoredIdentity_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistryStorage.modifyStoredIdentity(charlie, charlieIdentity);
    }

    /// @notice Should revert when identity is zero address
    function test_modifyStoredIdentity_RevertWhen_IdentityZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        identityRegistryStorage.addIdentityToStorage(charlie, charlieIdentity, 42);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.modifyStoredIdentity(charlie, IIdentity(address(0)));
    }

    /// @notice Should revert when wallet is zero address
    function test_modifyStoredIdentity_RevertWhen_WalletZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.modifyStoredIdentity(address(0), charlieIdentity);
    }

    /// @notice Should revert when wallet is not registered
    function test_modifyStoredIdentity_RevertWhen_NotStored() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(AddressNotYetStored.selector);
        identityRegistryStorage.modifyStoredIdentity(charlie, charlieIdentity);
    }

    // ============ modifyStoredInvestorCountry() Tests ============

    /// @notice Should revert when sender is not agent
    function test_modifyStoredInvestorCountry_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistryStorage.modifyStoredInvestorCountry(charlie, 42);
    }

    /// @notice Should revert when wallet is zero address
    function test_modifyStoredInvestorCountry_RevertWhen_WalletZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.modifyStoredInvestorCountry(address(0), 42);
    }

    /// @notice Should revert when wallet is not registered
    function test_modifyStoredInvestorCountry_RevertWhen_NotStored() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(AddressNotYetStored.selector);
        identityRegistryStorage.modifyStoredInvestorCountry(charlie, 42);
    }

    // ============ removeIdentityFromStorage() Tests ============

    /// @notice Should revert when sender is not agent
    function test_removeIdentityFromStorage_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        identityRegistryStorage.removeIdentityFromStorage(charlie);
    }

    /// @notice Should revert when wallet is zero address
    function test_removeIdentityFromStorage_RevertWhen_WalletZeroAddress() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.removeIdentityFromStorage(address(0));
    }

    /// @notice Should revert when wallet is not registered
    function test_removeIdentityFromStorage_RevertWhen_NotStored() public {
        vm.prank(deployer);
        identityRegistryStorage.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(AddressNotYetStored.selector);
        identityRegistryStorage.removeIdentityFromStorage(charlie);
    }

    // ============ bindIdentityRegistry() Tests ============

    /// @notice Should revert when sender is not owner
    function test_bindIdentityRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistryStorage.bindIdentityRegistry(address(charlieIdentity));
    }

    /// @notice Should revert when identity registry is zero address
    function test_bindIdentityRegistry_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.bindIdentityRegistry(address(0));
    }

    /// @notice Should revert when there are already 299 identity registries bound
    function test_bindIdentityRegistry_RevertWhen_MoreThan299Registries() public {
        // Add 300 registries (max is 300, so length 300 means we have 300 registries)
        // Check is length < 300, so when length is 299, we can add one more (300th)
        // When length is 300, we cannot add more (301st should fail)
        for (uint256 i = 0; i < 300; i++) {
            address registryAddress = vm.addr(i + 1000);
            vm.prank(deployer);
            identityRegistryStorage.bindIdentityRegistry(registryAddress);
        }

        // Try to add 301st registry (should fail, length is now 300, not < 300)
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxIRByIRSReached.selector, 300));
        identityRegistryStorage.bindIdentityRegistry(address(charlieIdentity));
    }

    // ============ unbindIdentityRegistry() Tests ============

    /// @notice Should revert when sender is not owner
    function test_unbindIdentityRegistry_RevertWhen_NotOwner() public {
        // Bind first
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(charlieIdentity));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        identityRegistryStorage.unbindIdentityRegistry(address(charlieIdentity));
    }

    /// @notice Should revert when identity registry is zero address
    function test_unbindIdentityRegistry_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        identityRegistryStorage.unbindIdentityRegistry(address(0));
    }

    /// @notice Should revert when identity registry is not bound
    function test_unbindIdentityRegistry_RevertWhen_NotBound() public {
        // Bind and then unbind
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(charlieIdentity));

        vm.prank(deployer);
        identityRegistryStorage.unbindIdentityRegistry(address(charlieIdentity));

        // Try to unbind again
        vm.prank(deployer);
        vm.expectRevert(IdentityRegistryNotStored.selector);
        identityRegistryStorage.unbindIdentityRegistry(address(charlieIdentity));
    }

    /// @notice Should unbind the identity registry
    function test_unbindIdentityRegistry_Success() public {
        // Deploy TrustedIssuersRegistry
        TrustedIssuersRegistryProxy trustedIssuersRegistryProxy =
            new TrustedIssuersRegistryProxy(address(implementationAuthority));
        TrustedIssuersRegistry trustedIssuersRegistry = TrustedIssuersRegistry(address(trustedIssuersRegistryProxy));
        trustedIssuersRegistry.transferOwnership(deployer);

        // Deploy ClaimTopicsRegistry
        ClaimTopicsRegistryProxy claimTopicsRegistryProxy =
            new ClaimTopicsRegistryProxy(address(implementationAuthority));
        ClaimTopicsRegistry claimTopicsRegistry = ClaimTopicsRegistry(address(claimTopicsRegistryProxy));
        claimTopicsRegistry.transferOwnership(deployer);

        // Deploy IdentityRegistry
        IdentityRegistryProxy identityRegistryProxy = new IdentityRegistryProxy(
            address(implementationAuthority),
            address(trustedIssuersRegistry),
            address(claimTopicsRegistry),
            address(identityRegistryStorage)
        );
        IdentityRegistry identityRegistry = IdentityRegistry(address(identityRegistryProxy));
        identityRegistry.transferOwnership(deployer);

        // Bind identityRegistry to storage (matching Hardhat fixture)
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(identityRegistry));

        // Bind charlie and bob identities
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(charlieIdentity));
        vm.prank(deployer);
        identityRegistryStorage.bindIdentityRegistry(address(bobIdentity));

        // Unbind charlieIdentity
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit IdentityRegistryUnbound(address(charlieIdentity));
        identityRegistryStorage.unbindIdentityRegistry(address(charlieIdentity));

        // Verify linked registries (should contain identityRegistry and bobIdentity in specific order)
        address[] memory linkedRegistries = identityRegistryStorage.linkedIdentityRegistries();
        assertEq(linkedRegistries.length, 2);
        assertEq(linkedRegistries[0], address(identityRegistry));
        assertEq(linkedRegistries[1], address(bobIdentity)); // bobIdentity was in index2, and now it is in index1
    }

    // ============ supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(identityRegistryStorage.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IERC3643IdentityRegistryStorage interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC3643IdentityRegistryStorage() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC3643IdentityRegistryStorageInterfaceId();
        assertTrue(identityRegistryStorage.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(identityRegistryStorage.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(identityRegistryStorage.supportsInterface(interfaceId));
    }

    // ============ Constructor Tests ============

    /// @notice Should revert when implementation authority is zero address
    function test_constructor_RevertWhen_ImplementationAuthorityZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new IdentityRegistryStorageProxy(address(0));
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid IRS implementation
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));

        // Create a version with invalid IRS implementation (mock contract without init())
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(mockImpl), // Invalid - doesn't have proper init
            ctrImplementation: address(mockImpl), // Invalid
            irImplementation: address(mockImpl), // Invalid
            irsImplementation: address(mockImpl), // Invalid - doesn't have init() function
            tirImplementation: address(mockImpl), // Invalid
            mcImplementation: address(mockImpl) // Invalid
        });

        // Add version to IA (need to be owner)
        Ownable(address(incompleteIA)).transferOwnership(deployer);
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        vm.expectRevert(InitializationFailed.selector);
        new IdentityRegistryStorageProxy(address(incompleteIA));
    }

}
