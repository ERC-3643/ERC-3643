// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IdFactory } from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { ITREXFactory, TREXFactory } from "contracts/factory/TREXFactory.sol";
import { AccessManagerSetupLib } from "contracts/libraries/AccessManagerSetupLib.sol";
import { ErrorsLib } from "contracts/libraries/ErrorsLib.sol";
import { TrustedIssuersRegistryProxy } from "contracts/proxy/TrustedIssuersRegistryProxy.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { Token } from "contracts/token/Token.sol";

import { TREXSuiteTest } from "../helpers/TREXSuiteTest.sol";
import { TestModule } from "../mocks/TestModule.sol";

contract TREXFactoryTest is TREXSuiteTest {

    // ============ Existing Basic Tests ============

    function test_TREXFactoryLinked() public view {
        // Verify factory knows about IA
        assertEq(
            trexFactory.getImplementationAuthority(),
            address(trexImplementationAuthority),
            "Factory should reference IA"
        );
        assertEq(trexFactory.getIdFactory(), address(idFactory), "Factory should reference IdFactory");
    }

    // ============ deployTREXSuite() Tests ============

    // Access Control Tests
    function test_deployTREXSuite_RevertWhen_NotOwner() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, another));
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
    }

    // Validation Tests
    function test_deployTREXSuite_RevertWhen_SaltAlreadyUsed() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        // First deployment should succeed
        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);

        // Second deployment with same salt should revert
        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.TokenAlreadyDeployed.selector);
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_InvalidClaimPattern() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();

        address[] memory issuers = new address[](1);
        issuers[0] = address(0x123);
        uint256[][] memory issuerClaims = new uint256[][](0); // Empty array - mismatch

        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: new uint256[](0), issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.InvalidClaimPattern.selector);
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
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
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxClaimIssuersReached.selector, 5));
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
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
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxClaimTopicsReached.selector, 5));
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan5Agents() public {
        address[] memory irAgents = new address[](6); // 6 agents > 5
        for (uint256 i = 0; i < 6; i++) {
            irAgents[i] = address(uint160(i + 100));
        }

        ITREXFactory.TokenDetails memory tokenDetails =
            _createTokenDetails(deployer, address(0), irAgents, new address[](0), new address[](0), new bytes[](0));

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxAgentsReached.selector, 5));
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_MoreThan30ComplianceModules() public {
        address[] memory complianceModules = new address[](31); // 31 modules > 30
        for (uint256 i = 0; i < 31; i++) {
            complianceModules[i] = address(uint160(i + 200));
        }

        ITREXFactory.TokenDetails memory tokenDetails = _createTokenDetails(
            deployer, address(0), new address[](0), new address[](0), complianceModules, new bytes[](0)
        );

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MaxModuleActionsReached.selector, 30));
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
    }

    function test_deployTREXSuite_RevertWhen_InvalidCompliancePattern() public {
        address[] memory complianceModules = new address[](1);
        complianceModules[0] = address(0x456);

        bytes[] memory complianceSettings = new bytes[](2); // 2 settings > 1 module

        ITREXFactory.TokenDetails memory tokenDetails = _createTokenDetails(
            deployer, address(0), new address[](0), new address[](0), complianceModules, complianceSettings
        );

        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.InvalidCompliancePattern.selector);
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);
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

        ITREXFactory.TokenDetails memory tokenDetails =
            _createTokenDetails(deployer, address(0), irAgents, tokenAgents, complianceModules, complianceSettings);

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
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);

        // Verify token was deployed
        address tokenAddress = trexFactory.getToken("salt2");
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
        trexFactory.deployTREXSuite("salt2", tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken("salt2");
        assertNotEq(tokenAddress, address(0), "Token address should not be zero");
    }

    // ============ setImplementationAuthority() Tests ============

    function test_setImplementationAuthority_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        trexFactory.setImplementationAuthority(address(0));
    }

    function test_setImplementationAuthority_RevertWhen_IncompleteIA() public {
        // Deploy a new IA but don't add any version (incomplete)
        TREXImplementationAuthority incompleteIA =
            new TREXImplementationAuthority(true, address(0), address(0), address(accessManager));
        vm.prank(accessManagerAdmin);
        AccessManagerSetupLib.setupTREXImplementationAuthorityRoles(accessManager, address(incompleteIA));

        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.InvalidImplementationAuthority.selector);
        trexFactory.setImplementationAuthority(address(incompleteIA));
    }

    function test_setImplementationAuthority_Success() public {
        // Deploy a complete IA using the helper
        TREXImplementationAuthority newIA = _deployTREXImplementationAuthority(true);

        vm.prank(deployer);
        trexFactory.setImplementationAuthority(address(newIA));

        assertEq(trexFactory.getImplementationAuthority(), address(newIA), "Implementation Authority should be updated");
    }

    // ============ setIdFactory() Tests ============

    function test_setIdFactory_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        trexFactory.setIdFactory(address(0));
    }

    function test_setIdFactory_Success() public {
        // Deploy a new IdFactory using the helper
        IdFactory newIdFactory = new IdFactory(address(trexImplementationAuthority));

        vm.prank(deployer);
        trexFactory.setIdFactory(address(newIdFactory));

        assertEq(trexFactory.getIdFactory(), address(newIdFactory), "IdFactory should be updated");
    }

    /// @notice Should revert when the CREATE2 target address already contains code
    function test_deployTREXSuite_RevertWhen_Create2AddressCollides() public {
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        string memory salt = "collision-salt";
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));

        // First contract deployed by deployTREXSuite is the TrustedIssuersRegistryProxy.
        // Predict its CREATE2 address and pre-populate code there so CREATE2 fails.
        bytes memory initCode = abi.encodePacked(
            type(TrustedIssuersRegistryProxy).creationCode,
            abi.encode(address(trexImplementationAuthority), address(accessManager))
        );
        address predicted = vm.computeCreate2Address(saltBytes, keccak256(initCode), address(trexFactory));
        vm.etch(predicted, hex"60006000");

        vm.prank(deployer);
        vm.expectRevert();
        trexFactory.deployTREXSuite(salt, tokenDetails, claimDetails);
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
        ITREXFactory.TokenDetails memory tokenDetails = _createTokenDetails(deployer, deployedIRS);
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
