// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { Token } from "contracts/token/Token.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract TransferCheckTest is TREXFactorySetup {

    UtilityChecker public utilityChecker;
    Token public token;
    IdentityRegistry public identityRegistry;
    ModularCompliance public compliance;
    TestModule public testModule;
    address public tokenAgent = makeAddr("tokenAgent");

    function setUp() public override {
        super.setUp();

        // Deploy token suite with claim topic (matching Hardhat fixture)
        uint256 claimTopic = 1;
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = claimTopic;

        ClaimIssuer claimIssuerContract = new ClaimIssuer(charlie);
        address[] memory issuers = new address[](1);
        issuers[0] = address(claimIssuerContract);

        uint256[][] memory issuerClaims = new uint256[][](1);
        uint256[] memory claims = new uint256[](1);
        claims[0] = claimTopic;
        issuerClaims[0] = claims;

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
        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: claimTopics, issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        token = Token(trexFactory.getToken("salt"));

        // Get IdentityRegistry
        IERC3643IdentityRegistry ir = token.identityRegistry();
        identityRegistry = IdentityRegistry(address(ir));

        // Add tokenAgent as an agent to Token and IdentityRegistry
        vm.prank(deployer);
        token.addAgent(tokenAgent);
        vm.prank(deployer);
        identityRegistry.addAgent(tokenAgent);

        // Register alice and bob in IdentityRegistry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);

        // Set up claim issuer signing key and add claims for alice and bob
        uint256 claimIssuerSigningKeyPrivateKey = 0x12345;
        address claimIssuerSigningKeyAddress = vm.addr(claimIssuerSigningKeyPrivateKey);
        bytes32 signingKeyHash = keccak256(abi.encode(claimIssuerSigningKeyAddress));
        vm.prank(charlie);
        claimIssuerContract.addKey(signingKeyHash, 3, 1); // purpose 3 = CLAIM, keyType 1 = ECDSA

        // Add claims to alice and bob's identities
        bytes memory claimData = "Some claim public data.";
        _addClaim(
            aliceIdentity, claimTopic, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuerContract), alice
        );
        _addClaim(
            bobIdentity, claimTopic, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuerContract), bob
        );

        // Mint tokens to alice (1000) and bob (500)
        vm.prank(tokenAgent);
        token.mint(alice, 1000);
        vm.prank(tokenAgent);
        token.mint(bob, 500);

        // Unpause token
        vm.prank(tokenAgent);
        token.unpause();

        // Deploy compliance and test module
        _deployComplianceSetup();

        // Deploy UtilityChecker
        utilityChecker = new UtilityChecker();
        utilityChecker.initialize();
    }

    /// @notice Helper function to create and add a claim to an identity
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

    /// @notice Helper to deploy TestModule + ModularCompliance setup
    function _deployComplianceSetup() internal {
        // Deploy ModularCompliance implementation
        ModularCompliance complianceImplementation = new ModularCompliance();

        // Deploy ModularCompliance proxy with init using ERC1967Proxy
        bytes memory initData = abi.encodeWithSelector(ModularCompliance.init.selector);
        ERC1967Proxy complianceProxy = new ERC1967Proxy(address(complianceImplementation), initData);
        compliance = ModularCompliance(address(complianceProxy));

        // Transfer ownership to deployer
        compliance.transferOwnership(deployer);

        // Set compliance on token
        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Deploy TestModule implementation
        TestModule testModuleImplementation = new TestModule();

        // Deploy TestModule proxy with initialize using ModuleProxy
        bytes memory moduleInitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModuleProxy = new ModuleProxy(address(testModuleImplementation), moduleInitData);
        testModule = TestModule(address(testModuleProxy));

        // Add module to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule));

        // Bind token to compliance
        vm.prank(deployer);
        compliance.bindToken(address(token));
    }

    // ============ getTransferStatus() Tests ============

    /// @notice Should return false when sender is frozen
    function test_getTransferStatus_ReturnsFalse_WhenSenderIsFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(alice, true);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when recipient is frozen
    function test_getTransferStatus_ReturnsFalse_WhenRecipientIsFrozen() public {
        vm.prank(tokenAgent);
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
        vm.prank(tokenAgent);
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
        vm.prank(tokenAgent);
        identityRegistry.updateCountry(bob, 42);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when no identity is registered
    function test_getTransferStatus_ReturnsFalse_WhenNoIdentityRegistered() public {
        // Delete bob's identity
        vm.prank(tokenAgent);
        identityRegistry.deleteIdentity(bob);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertFalse(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when identity is registered with topics but no claims
    function test_getTransferStatus_ReturnsFalse_WhenIdentityRegisteredWithTopics() public {
        // Register charlie (but no claims)
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(charlie, charlieIdentity, 0);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, charlie, 100);

        assertTrue(freezeStatus);
        assertFalse(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return true after TREXFactorySetup
    function test_getTransferStatus_ReturnsTrue_AfterSetup() public {
        // Update bob's country to ensure eligibility
        vm.prank(tokenAgent);
        identityRegistry.updateCountry(bob, 42);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when token is paused
    function test_getTransferStatus_ReturnsFalse_WhenTokenPaused() public {
        // Pause the token
        vm.prank(tokenAgent);
        token.pause();

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertFalse(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus);
    }

    /// @notice Should return false when compliance check fails
    function test_getTransferStatus_ReturnsFalse_WhenComplianceCheckFails() public {
        // Block the test module
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule));

        // Update bob's country to ensure eligibility
        vm.prank(tokenAgent);
        identityRegistry.updateCountry(bob, 42);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertFalse(complianceStatus); // Should be false when module check fails
    }

    /// @notice Should return true when all checks pass including compliance
    function test_getTransferStatus_ReturnsTrue_WhenAllChecksPass() public {
        // Update bob's country to ensure eligibility
        vm.prank(tokenAgent);
        identityRegistry.updateCountry(bob, 42);

        (bool freezeStatus, bool eligibilityStatus, bool complianceStatus) =
            utilityChecker.getTransferStatus(address(token), alice, bob, 100);

        assertTrue(freezeStatus);
        assertTrue(eligibilityStatus);
        assertTrue(complianceStatus); // Should be true when all modules pass
    }

}
