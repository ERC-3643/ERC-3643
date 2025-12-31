// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { TREXFactory } from "contracts/factory/TREXFactory.sol";
import { ModularComplianceProxy } from "contracts/proxy/ModularComplianceProxy.sol";
import { IAFactory } from "contracts/proxy/authority/IAFactory.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import {
    IAFactorySet,
    ImplementationAuthorityChanged,
    TREXFactorySet,
    TREXVersionAdded,
    TREXVersionFetched,
    VersionUpdated
} from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import {
    CallerNotOwnerOfAllImpactedContracts,
    CannotCallOnReferenceContract,
    InvalidImplementationAuthority,
    NewIAIsNotAReferenceContract,
    NonExistingVersion,
    OnlyReferenceContractCanCall,
    VersionAlreadyExists,
    VersionAlreadyFetched,
    VersionAlreadyInUse,
    VersionOfNewIAMustBeTheSameAsCurrentIA
} from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { Token } from "contracts/token/Token.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract TREXImplementationAuthorityTest is TREXFactorySetup {

    // Token suite deployed in setUp()
    address public tokenAddress;

    function setUp() public override {
        super.setUp();

        // Deploy token suite once for all tests
        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "TREXDINO",
            symbol: "TREX",
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
        tokenAddress = trexFactory.getToken("salt");

        // Transfer IRS ownership to deployer (IRS is owned by factory after deployment)
        address irAddress = address(Token(tokenAddress).identityRegistry());
        address irsAddress = address(IERC3643IdentityRegistry(irAddress).identityStorage());
        vm.prank(address(trexFactory));
        Ownable(irsAddress).transferOwnership(deployer);
    }

    // ============ setTREXFactory() Tests ============

    /// @notice Should revert when called by not owner
    function test_setTREXFactory_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        getTREXImplementationAuthority().setTREXFactory(address(0));
    }

    /// @notice Should revert when trex factory to add is not using this authority contract
    function test_setTREXFactory_RevertWhen_FactoryNotUsingThisAuthority() public {
        // Deploy another IA and factory using it
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory otherIASetup =
            ImplementationAuthorityHelper.deploy(true);

        Ownable(address(otherIASetup.implementationAuthority)).transferOwnership(deployer);

        TREXFactory otherFactory =
            new TREXFactory(address(otherIASetup.implementationAuthority), address(getIdFactory()));
        Ownable(address(otherFactory)).transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(OnlyReferenceContractCanCall.selector);
        getTREXImplementationAuthority().setTREXFactory(address(otherFactory));
    }

    /// @notice Should set the trex factory address
    function test_setTREXFactory_Success() public {
        // Deploy a new factory using this IA
        TREXFactory newFactory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(newFactory)).transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit TREXFactorySet(address(newFactory));
        getTREXImplementationAuthority().setTREXFactory(address(newFactory));

        assertEq(getTREXImplementationAuthority().getTREXFactory(), address(newFactory));
    }

    // ============ setIAFactory() Tests ============

    /// @notice Should revert when called by not owner
    function test_setIAFactory_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        getTREXImplementationAuthority().setIAFactory(address(0));
    }

    /// @notice Should set the IA factory address
    function test_setIAFactory_Success() public {
        // First set TREXFactory (required for setIAFactory)
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        // Deploy IAFactory
        IAFactory iaFactory = new IAFactory(address(trexFactory));

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit IAFactorySet(address(iaFactory));
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));
    }

    /// @notice Should revert when setIAFactory is called on reference contract but factory references different IA
    /// @dev isReferenceContract() is true but getImplementationAuthority() != address(this)
    function test_setIAFactory_RevertWhen_FactoryReferencesDifferentIA() public {
        // Deploy another reference IA and factory using it
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory otherIASetup =
            ImplementationAuthorityHelper.deploy(true);
        Ownable(address(otherIASetup.implementationAuthority)).transferOwnership(deployer);

        TREXFactory otherFactory =
            new TREXFactory(address(otherIASetup.implementationAuthority), address(getIdFactory()));
        Ownable(address(otherFactory)).transferOwnership(deployer);

        // Create a new reference IA with the other factory in constructor
        // This factory references otherIASetup, not this IA
        TREXImplementationAuthority newIA = new TREXImplementationAuthority(
            true, // is reference
            address(otherFactory), // factory that references a different IA
            address(0) // no IAFactory
        );
        Ownable(address(newIA)).transferOwnership(deployer);

        // Now try to set IAFactory - should revert because otherFactory.getImplementationAuthority() != address(newIA)
        IAFactory iaFactory = new IAFactory(address(otherFactory));

        vm.prank(deployer);
        vm.expectRevert(OnlyReferenceContractCanCall.selector);
        newIA.setIAFactory(address(iaFactory));
    }

    // ============ fetchVersion() Tests ============

    /// @notice Should revert when called on the reference contract
    function test_fetchVersion_RevertWhen_OnReferenceContract() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        vm.prank(deployer);
        vm.expectRevert(CannotCallOnReferenceContract.selector);
        getTREXImplementationAuthority().fetchVersion(version);
    }

    /// @notice Should revert when version was already fetched
    function test_fetchVersion_RevertWhen_AlreadyFetched() public {
        TREXFactory factory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(factory)).transferOwnership(deployer);

        // Deploy non-reference IA
        TREXImplementationAuthority otherIA =
            new TREXImplementationAuthority(false, address(factory), address(getTREXImplementationAuthority()));
        Ownable(address(otherIA)).transferOwnership(deployer);

        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        // Fetch version first time
        vm.prank(deployer);
        otherIA.fetchVersion(version);

        // Try to fetch again
        vm.prank(deployer);
        vm.expectRevert(VersionAlreadyFetched.selector);
        otherIA.fetchVersion(version);
    }

    /// @notice Should fetch and set the versions from the reference contract
    function test_fetchVersion_Success() public {
        TREXFactory factory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(factory)).transferOwnership(deployer);

        // Deploy non-reference IA
        TREXImplementationAuthority otherIA =
            new TREXImplementationAuthority(false, address(factory), address(getTREXImplementationAuthority()));

        Ownable(address(otherIA)).transferOwnership(deployer);

        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        vm.prank(deployer);
        otherIA.fetchVersion(version);

        // Verify version was fetched by checking it exists
        ITREXImplementationAuthority.TREXContracts memory fetchedContracts = otherIA.getContracts(version);
        assertNotEq(fetchedContracts.tokenImplementation, address(0), "Version should be fetched");
    }

    // ============ addTREXVersion() Tests ============

    /// @notice Should revert when called not as owner
    function test_addTREXVersion_RevertWhen_NotOwner() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 1 });
        ITREXImplementationAuthority.TREXContracts memory contracts = getTREXContracts();

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        getTREXImplementationAuthority().addTREXVersion(version, contracts);
    }

    /// @notice Should revert when called on a non-reference contract
    function test_addTREXVersion_RevertWhen_NonReferenceContract() public {
        TREXFactory factory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(factory)).transferOwnership(deployer);

        // Deploy non-reference IA
        TREXImplementationAuthority otherIA =
            new TREXImplementationAuthority(false, address(factory), address(getTREXImplementationAuthority()));
        Ownable(address(otherIA)).transferOwnership(deployer);

        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });
        ITREXImplementationAuthority.TREXContracts memory contracts = getTREXContracts();

        vm.prank(deployer);
        vm.expectRevert(OnlyReferenceContractCanCall.selector);
        otherIA.addTREXVersion(version, contracts);
    }

    /// @notice Should revert when version was already added
    function test_addTREXVersion_RevertWhen_AlreadyExists() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });
        ITREXImplementationAuthority.TREXContracts memory contracts = getTREXContracts();

        vm.prank(deployer);
        vm.expectRevert(VersionAlreadyExists.selector);
        getTREXImplementationAuthority().addTREXVersion(version, contracts);
    }

    /// @notice Should revert when a contract implementation address is zero address
    function test_addTREXVersion_RevertWhen_ZeroAddress() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 1 });
        ITREXImplementationAuthority.TREXContracts memory contracts = getTREXContracts();
        contracts.irsImplementation = address(0); // Set one to zero

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        getTREXImplementationAuthority().addTREXVersion(version, contracts);
    }

    // ============ useTREXVersion() Tests ============

    /// @notice Should revert when called not as owner
    function test_useTREXVersion_RevertWhen_NotOwner() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        getTREXImplementationAuthority().useTREXVersion(version);
    }

    /// @notice Should revert when version is already in use
    function test_useTREXVersion_RevertWhen_AlreadyInUse() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        vm.prank(deployer);
        vm.expectRevert(VersionAlreadyInUse.selector);
        getTREXImplementationAuthority().useTREXVersion(version);
    }

    /// @notice Should revert when version does not exist
    function test_useTREXVersion_RevertWhen_NonExistingVersion() public {
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 1 });

        vm.prank(deployer);
        vm.expectRevert(NonExistingVersion.selector);
        getTREXImplementationAuthority().useTREXVersion(version);
    }

    // ============ changeImplementationAuthority() Tests ============

    /// @notice Should revert when token to update is zero address
    function test_changeImplementationAuthority_RevertWhen_TokenZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        getTREXImplementationAuthority().changeImplementationAuthority(address(0), address(0));
    }

    /// @notice Should revert when new authority is zero address on non-reference contract
    function test_changeImplementationAuthority_RevertWhen_ZeroAddressOnNonReference() public {
        TREXFactory factory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(factory)).transferOwnership(deployer);

        // Deploy non-reference IA
        TREXImplementationAuthority otherIA =
            new TREXImplementationAuthority(false, address(factory), address(getTREXImplementationAuthority()));
        Ownable(address(otherIA)).transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(OnlyReferenceContractCanCall.selector);
        otherIA.changeImplementationAuthority(tokenAddress, address(0));
    }

    /// @notice Should revert when caller is not owner of all impacted contracts
    function test_changeImplementationAuthority_RevertWhen_NotOwnerOfAllContracts() public {
        vm.prank(another);
        vm.expectRevert(CallerNotOwnerOfAllImpactedContracts.selector);
        getTREXImplementationAuthority().changeImplementationAuthority(tokenAddress, address(0));
    }

    /// @notice Should deploy a new authority contract when caller is owner
    function test_changeImplementationAuthority_Success_DeployNewIA() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        vm.prank(deployer);
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));

        ModularComplianceProxy compliance = new ModularComplianceProxy(address(getTREXImplementationAuthority()));

        // Transfer compliance ownership to deployer (compliance is owned by test contract after deployment)
        Ownable(address(compliance)).transferOwnership(deployer);
        vm.prank(deployer);
        Token(tokenAddress).setCompliance(address(compliance));

        vm.prank(deployer);
        // When address(0) is passed, a new IA is deployed
        // The event will have the actual deployed IA address (not address(0))
        // So we only check the token parameter (indexed) and verify it doesn't revert
        vm.expectEmit(true, false, false, false);
        emit ImplementationAuthorityChanged(tokenAddress, address(0)); // Only token parameter will match
        getTREXImplementationAuthority().changeImplementationAuthority(tokenAddress, address(0));
    }

    /// @notice Should revert when version of new IA is not the same as current
    function test_changeImplementationAuthority_RevertWhen_VersionMismatch() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        vm.prank(deployer);
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));

        // Replace compliance with a new one
        ModularComplianceProxy compliance = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(compliance)).transferOwnership(deployer);
        vm.prank(deployer);
        Token(tokenAddress).setCompliance(address(compliance));

        // Deploy another reference IA with different version
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory otherIASetup =
            ImplementationAuthorityHelper.deploy(true);
        Ownable(address(otherIASetup.implementationAuthority)).transferOwnership(deployer);

        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 1 });
        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(otherIASetup.implementations.token),
            ctrImplementation: address(otherIASetup.implementations.claimTopicsRegistry),
            irImplementation: address(otherIASetup.implementations.identityRegistry),
            irsImplementation: address(otherIASetup.implementations.identityRegistryStorage),
            tirImplementation: address(otherIASetup.implementations.trustedIssuersRegistry),
            mcImplementation: address(otherIASetup.implementations.modularCompliance)
        });
        vm.prank(deployer);
        otherIASetup.implementationAuthority.addAndUseTREXVersion(version, contracts);

        vm.prank(deployer);
        vm.expectRevert(VersionOfNewIAMustBeTheSameAsCurrentIA.selector);
        getTREXImplementationAuthority()
            .changeImplementationAuthority(tokenAddress, address(otherIASetup.implementationAuthority));
    }

    /// @notice Should revert when new IA is a reference contract but not current one
    function test_changeImplementationAuthority_RevertWhen_NewIAIsReferenceButNotCurrent() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        vm.prank(deployer);
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));

        // Replace compliance with a new one
        ModularComplianceProxy compliance = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(compliance)).transferOwnership(deployer);
        vm.prank(deployer);
        Token(tokenAddress).setCompliance(address(compliance));

        // Deploy another reference IA - it already has version 4.0.0 set up from deploy()
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory otherIASetup =
            ImplementationAuthorityHelper.deploy(true);
        Ownable(address(otherIASetup.implementationAuthority)).transferOwnership(deployer);

        // Note: otherIASetup already has version 4.0.0 added and in use from deploy(),
        // so we don't need to call addAndUseTREXVersion again

        vm.prank(deployer);
        vm.expectRevert(NewIAIsNotAReferenceContract.selector);
        getTREXImplementationAuthority()
            .changeImplementationAuthority(tokenAddress, address(otherIASetup.implementationAuthority));
    }

    /// @notice Should revert when new IA is not valid
    function test_changeImplementationAuthority_RevertWhen_InvalidIA() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        vm.prank(deployer);
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));

        // Replace compliance with a new one
        ModularComplianceProxy compliance = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(compliance)).transferOwnership(deployer);
        vm.prank(deployer);
        Token(tokenAddress).setCompliance(address(compliance));

        // Deploy non-reference IA that fetched version but not deployed by factory
        TREXFactory factory = new TREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));
        Ownable(address(factory)).transferOwnership(deployer);

        TREXImplementationAuthority otherIA =
            new TREXImplementationAuthority(false, address(factory), address(getTREXImplementationAuthority()));
        Ownable(address(otherIA)).transferOwnership(deployer);

        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });
        vm.prank(deployer);
        otherIA.fetchVersion(version);
        vm.prank(deployer);
        otherIA.useTREXVersion(version);

        vm.prank(deployer);
        vm.expectRevert(InvalidImplementationAuthority.selector);
        getTREXImplementationAuthority().changeImplementationAuthority(tokenAddress, address(otherIA));
    }

    /// @notice Should succeed when changing to the reference contract itself
    /// @dev  _newImplementationAuthority == getReferenceContract()
    function test_changeImplementationAuthority_Success_WithReferenceContract() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        vm.prank(deployer);
        getTREXImplementationAuthority().setIAFactory(address(iaFactory));

        // Replace compliance with a new one
        ModularComplianceProxy compliance = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(compliance)).transferOwnership(deployer);
        vm.prank(deployer);
        Token(tokenAddress).setCompliance(address(compliance));

        // Change to the reference contract itself (getReferenceContract() returns this IA)
        address referenceContract = getTREXImplementationAuthority().getReferenceContract();
        assertEq(referenceContract, address(getTREXImplementationAuthority()), "Should be the reference contract");

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ImplementationAuthorityChanged(tokenAddress, referenceContract);
        getTREXImplementationAuthority().changeImplementationAuthority(tokenAddress, referenceContract);
    }

    // ============ supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(getTREXImplementationAuthority().supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the ITREXImplementationAuthority interface ID
    function test_supportsInterface_ReturnsTrue_ForITREXImplementationAuthority() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getITREXImplementationAuthorityInterfaceId();
        assertTrue(getTREXImplementationAuthority().supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(getTREXImplementationAuthority().supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(getTREXImplementationAuthority().supportsInterface(interfaceId));
    }

    // ============ IAFactory supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces (IAFactory)
    function test_IAFactory_supportsInterface_ReturnsFalse_ForUnsupported() public {
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(iaFactory.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IIAFactory interface ID
    function test_IAFactory_supportsInterface_ReturnsTrue_ForIIAFactory() public {
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIIAFactoryInterfaceId();
        assertTrue(iaFactory.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID (IAFactory)
    function test_IAFactory_supportsInterface_ReturnsTrue_ForIERC165() public {
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(iaFactory.supportsInterface(interfaceId));
    }

    // ============ IAFactory deployIA() Tests ============

    /// @notice Should revert when deployIA is called from non-reference IA
    /// @dev just the reference implementation authority can call the iaFactory to deploy new implementation authority for a specific token
    function test_deployIA_RevertWhen_NotFromReferenceIA() public {
        // Setup TREXFactory and IAFactory
        vm.prank(deployer);
        getTREXImplementationAuthority().setTREXFactory(address(trexFactory));

        IAFactory iaFactory = new IAFactory(address(trexFactory));

        // Use a simple address that is not the reference IA
        // The check at line 90 should fail: trexFactory.getImplementationAuthority() != msg.sender
        address nonReferenceIA = makeAddr("nonReferenceIA");

        // Try to call deployIA from a non-reference address
        // This should revert at line 90 because msg.sender != trexFactory.getImplementationAuthority()
        vm.prank(nonReferenceIA);
        vm.expectRevert(IAFactory.OnlyReferenceIACanDeploy.selector);
        iaFactory.deployIA(tokenAddress);
    }

}
