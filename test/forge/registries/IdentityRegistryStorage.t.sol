// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IdentityProxy } from "@onchain-id/solidity/contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { CallerDoesNotHaveAgentRole } from "contracts/errors/RoleErrors.sol";
import { ClaimTopicsRegistryProxy } from "contracts/proxy/ClaimTopicsRegistryProxy.sol";
import { IdentityRegistryProxy } from "contracts/proxy/IdentityRegistryProxy.sol";
import { IdentityRegistryStorageProxy } from "contracts/proxy/IdentityRegistryStorageProxy.sol";
import { TrustedIssuersRegistryProxy } from "contracts/proxy/TrustedIssuersRegistryProxy.sol";
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
import { IdentityFactoryHelper } from "test/forge/helpers/IdentityFactoryHelper.sol";
import { ImplementationAuthorityHelper } from "test/forge/helpers/ImplementationAuthorityHelper.sol";

contract IdentityRegistryStorageTest is Test {

    // Error declaration, from OpenZeppelin Initializable
    error InvalidInitialization();

    // Event declarations for expectEmit
    event IdentityStored(address indexed _userAddress, address indexed _identity);
    event IdentityModified(address indexed _oldIdentity, address indexed _newIdentity);
    event CountryModified(address indexed _investorAddress, uint16 indexed _country);
    event IdentityUnstored(address indexed _userAddress, address indexed _identity);
    event IdentityRegistryBound(address indexed _identityRegistry);
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    // Contracts
    IdentityRegistryStorage public identityRegistryStorage;
    TREXImplementationAuthority public implementationAuthority;
    ImplementationAuthority public identityImplementationAuthority; // For Identity proxies

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
        // Get the ImplementationAuthority from IdFactory
        address identityImplementationAuthorityAddress = onchainidSetup.idFactory.implementationAuthority();
        identityImplementationAuthority = ImplementationAuthority(identityImplementationAuthorityAddress);

        // Deploy Identity proxies for bob and charlie
        bobIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), bob)));
        charlieIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), charlie)));

        // Note: In Hardhat fixture, identityRegistry.target is bound to storage in setUp
        // For Foundry, we start with 0 bound registries (tests will bind as needed)
    }

    // ============ init() Tests ============

    /// @notice Should revert when contract was already initialized
    function test_init_RevertWhen_AlreadyInitialized() public {
        vm.prank(deployer);
        vm.expectRevert(InvalidInitialization.selector);
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

}
