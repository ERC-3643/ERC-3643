// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { IERC3643IdentityRegistryStorage } from "contracts/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { TestTREXFactory } from "contracts/_testContracts/TestTREXFactory.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { InvalidImplementationAuthority } from "contracts/errors/CommonErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import {
    InvalidClaimPattern,
    InvalidCompliancePattern,
    MaxAgentsReached,
    MaxClaimIssuersReached,
    MaxClaimTopicsReached,
    MaxModuleActionsReached,
    TREXFactory,
    TokenAlreadyDeployed
} from "contracts/factory/TREXFactory.sol";
import { IdentityRegistryStorageProxy } from "contracts/proxy/IdentityRegistryStorageProxy.sol";
import { TrustedIssuersRegistryProxy } from "contracts/proxy/TrustedIssuersRegistryProxy.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { OwnableOnceNext2StepUpgradeable } from "contracts/roles/OwnableOnceNext2StepUpgradeable.sol";
import { OwnershipTransferStarted } from "contracts/roles/OwnableOnceNext2StepUpgradeable.sol";
import { Token } from "contracts/token/Token.sol";
import { Test } from "forge-std/Test.sol";
import { IdentityFactoryHelper } from "test/helpers/IdentityFactoryHelper.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract TREXFactoryTest is TREXFactorySetup {

    // Helper function to create empty TokenDetails
    function _createEmptyTokenDetails() internal view returns (ITREXFactory.TokenDetails memory) {
        address[] memory emptyAgents;
        address[] memory emptyModules;
        bytes[] memory emptySettings;

        return ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: emptyAgents,
            tokenAgents: emptyAgents,
            complianceModules: emptyModules,
            complianceSettings: emptySettings
        });
    }

    // Helper function to create empty ClaimDetails
    function _createEmptyClaimDetails() internal pure returns (ITREXFactory.ClaimDetails memory) {
        uint256[] memory emptyTopics;
        address[] memory emptyIssuers;
        uint256[][] memory emptyClaims;

        return ITREXFactory.ClaimDetails({ claimTopics: emptyTopics, issuers: emptyIssuers, issuerClaims: emptyClaims });
    }

    // ============ Existing Basic Tests ============

    function test_TREXSuiteDeploys() public view {
        // Verify all components are deployed
        assertNotEq(address(trexFactory), address(0), "TREX Factory should be deployed");
        assertNotEq(address(getTREXImplementationAuthority()), address(0), "TREX IA should be deployed");
        assertNotEq(address(getIdFactory()), address(0), "IdFactory should be deployed");
    }

    function test_TREXFactoryLinked() public view {
        TREXFactory factory = trexFactory;
        TREXImplementationAuthority ia = getTREXImplementationAuthority();

        // Verify factory knows about IA
        assertEq(factory.getImplementationAuthority(), address(ia), "Factory should reference IA");
        assertEq(factory.getIdFactory(), address(getIdFactory()), "Factory should reference IdFactory");
    }

    // ============ deployTREXSuite() Tests ============

    // Access Control Tests
    function test_deployTREXSuite_RevertWhen_NotOwner() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    // Validation Tests
    function test_deployTREXSuite_RevertWhen_SaltAlreadyUsed() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        // First deployment should succeed
        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);

        // Second deployment with same salt should revert
        vm.prank(deployer);
        vm.expectRevert(TokenAlreadyDeployed.selector);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_InvalidClaimPattern() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();

        address[] memory issuers = new address[](1);
        issuers[0] = address(0x123);
        uint256[][] memory issuerClaims = new uint256[][](0); // Empty array - mismatch

        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: new uint256[](0), issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        vm.expectRevert(InvalidClaimPattern.selector);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan5ClaimIssuers() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();

        address[] memory issuers = new address[](6); // 6 issuers > 5
        uint256[][] memory issuerClaims = new uint256[][](6);

        for (uint256 i = 0; i < 6; i++) {
            issuers[i] = address(uint160(i + 1));
            issuerClaims[i] = new uint256[](0);
        }

        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: new uint256[](0), issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxClaimIssuersReached.selector, 5));
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan5ClaimTopics() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();

        uint256[] memory claimTopics = new uint256[](6); // 6 topics > 5
        for (uint256 i = 0; i < 6; i++) {
            claimTopics[i] = uint256(i);
        }

        ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
            claimTopics: claimTopics, issuers: new address[](0), issuerClaims: new uint256[][](0)
        });

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxClaimTopicsReached.selector, 5));
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan5Agents() public {
        address[] memory irAgents = new address[](6); // 6 agents > 5
        for (uint256 i = 0; i < 6; i++) {
            irAgents[i] = address(uint160(i + 100));
        }

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: irAgents,
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxAgentsReached.selector, 5));
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan30ComplianceModules() public {
        address[] memory complianceModules = new address[](31); // 31 modules > 30
        for (uint256 i = 0; i < 31; i++) {
            complianceModules[i] = address(uint160(i + 200));
        }

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: complianceModules,
            complianceSettings: new bytes[](0)
        });

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxModuleActionsReached.selector, 30));
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_InvalidCompliancePattern() public {
        address[] memory complianceModules = new address[](1);
        complianceModules[0] = address(0x456);

        bytes[] memory complianceSettings = new bytes[](2); // 2 settings > 1 module

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: complianceModules,
            complianceSettings: complianceSettings
        });

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(InvalidCompliancePattern.selector);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_Success() public {
        // Deploy TestModule (implementation + proxy)
        TestModule testModuleImplementation = new TestModule();
        bytes memory initData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModuleProxy = new ModuleProxy(address(testModuleImplementation), initData);
        TestModule testModule = TestModule(address(testModuleProxy));

        // Deploy ClaimIssuer
        ClaimIssuer claimIssuer = new ClaimIssuer(charlie);

        // Prepare TokenDetails with agents and modules
        address[] memory irAgents = new address[](1);
        irAgents[0] = alice;
        address[] memory tokenAgents = new address[](1);
        tokenAgents[0] = bob;
        address[] memory complianceModules = new address[](1);
        complianceModules[0] = address(testModule);

        // Encode blockModule function call, this function is included in the TestModule
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        bytes[] memory complianceSettings = new bytes[](1);
        complianceSettings[0] = blockModuleCall;

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: irAgents,
            tokenAgents: tokenAgents,
            complianceModules: complianceModules,
            complianceSettings: complianceSettings
        });

        // Prepare ClaimDetails
        uint256 claimTopic = 1;
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = claimTopic;

        address[] memory issuers = new address[](1);
        issuers[0] = address(claimIssuer);

        uint256[][] memory issuerClaims = new uint256[][](1);
        uint256[] memory claims = new uint256[](1);
        claims[0] = claimTopic;
        issuerClaims[0] = claims;

        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: claimTopics, issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);

        // Verify token was deployed
        address tokenAddress = trexFactory.getToken("salt");
        assertNotEq(tokenAddress, address(0), "Token should be deployed");

        // Verify token configuration
        Token token = Token(tokenAddress);
        assertEq(token.name(), "Token name", "Token name should match");
        assertEq(token.symbol(), "SYM", "Token symbol should match");
    }

    // ============ getToken() Tests ============

    function test_getToken_ReturnsTokenAddress() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken("salt");
        assertNotEq(tokenAddress, address(0), "Token address should not be zero");
    }

    // ============ setImplementationAuthority() Tests ============

    function test_setImplementationAuthority_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        trexFactory.setImplementationAuthority(address(0));
    }

    function test_setImplementationAuthority_RevertWhen_IncompleteIA() public {
        // Deploy a new IA but don't add any version (incomplete)
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));
        Ownable(address(incompleteIA)).transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(InvalidImplementationAuthority.selector);
        trexFactory.setImplementationAuthority(address(incompleteIA));
    }

    function test_setImplementationAuthority_Success() public {
        // Deploy a complete IA using the helper
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory newIASetup =
            ImplementationAuthorityHelper.deploy(true);
        Ownable(address(newIASetup.implementationAuthority)).transferOwnership(deployer);

        vm.prank(deployer);
        trexFactory.setImplementationAuthority(address(newIASetup.implementationAuthority));

        assertEq(
            trexFactory.getImplementationAuthority(),
            address(newIASetup.implementationAuthority),
            "Implementation Authority should be updated"
        );
    }

    function test_deployTREXSuite_RevertWhen_CREATE2Fails() public {
        // Deploy test factory that invoke the internal functon _deploy
        TestTREXFactory testFactory =
            new TestTREXFactory(address(getTREXImplementationAuthority()), address(getIdFactory()));

        // Use empty bytecode so the CREATE2 will return address(0)
        bytes memory emptyBytecode = new bytes(0);

        vm.expectRevert(); // Should revert from the assembly revert(0, 0) because CREATE2 will return address(0) so the extcodesize(address(0)) = 0
        testFactory.testDeploy("test-salt-empty", emptyBytecode);
    }

    // ============ setIdFactory() Tests ============

    function test_setIdFactory_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        trexFactory.setIdFactory(address(0));
    }

    function test_setIdFactory_Success() public {
        // Deploy a new IdFactory using the helper
        IdentityFactoryHelper.ONCHAINIDSetup memory newSetup = IdentityFactoryHelper.deploy(deployer);
        address newIdFactory = address(newSetup.idFactory);

        vm.prank(deployer);
        trexFactory.setIdFactory(newIdFactory);

        assertEq(trexFactory.getIdFactory(), newIdFactory, "IdFactory should be updated");
    }

    // ============ recoverContractOwnership() Tests ============

    function test_recoverContractOwnership_RevertWhen_NotOwner() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken("salt");

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        trexFactory.recoverContractOwnership(tokenAddress, another);
    }

    function test_recoverContractOwnership_Success() public {
        // Deploy TREXSuite with factory as owner
        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: address(trexFactory), // Factory as owner
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken("salt");
        Token token = Token(tokenAddress);

        // Verify factory is the owner
        assertEq(token.owner(), address(trexFactory), "Factory should be owner");

        // Expect OwnershipTransferStarted event - check both indexed params
        vm.expectEmit(true, true, false, false, tokenAddress);
        emit OwnershipTransferStarted(address(trexFactory), alice);
        vm.prank(deployer);
        trexFactory.recoverContractOwnership(tokenAddress, alice);

        // Accept ownership
        vm.prank(alice);
        token.acceptOwnership();

        // Verify alice is now the owner
        assertEq(token.owner(), alice, "Alice should be the new owner");
    }

    /// @notice Should deploy TREX suite when irs is provided (not address(0))
    function test_deployTREXSuite_Success_WithProvidedIRS() public {
        // First deploy a TREX suite to get an IRS that's already properly set up
        ITREXFactory.TokenDetails memory tempTokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory tempClaimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("temp-salt", tempTokenDetails, tempClaimDetails);

        // Get the IRS from the deployed token's identity registry
        address tempTokenAddress = trexFactory.getToken("temp-salt");
        Token tempToken = Token(tempTokenAddress);
        address irAddress = address(tempToken.identityRegistry());
        IERC3643IdentityRegistry ir = IERC3643IdentityRegistry(irAddress);
        address deployedIRS = address(ir.identityStorage());

        require(deployedIRS != address(0), "IRS should be deployed");

        // Now use the deployed IRS in a new deployment
        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: deployedIRS, // Use provided IRS instead of address(0)
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt-irs", tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken("salt-irs");
        assertNotEq(tokenAddress, address(0), "Token should be deployed");

        // Verify both tokens share the same identity registry storage
        Token newToken = Token(tokenAddress);
        IERC3643IdentityRegistry newIR = newToken.identityRegistry();
        IERC3643IdentityRegistry tempIR = tempToken.identityRegistry();
        assertEq(
            address(newIR.identityStorage()),
            address(tempIR.identityStorage()),
            "Both tokens should share the same identity registry storage"
        );
    }

}
