// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IERC3643ClaimTopicsRegistry } from "contracts/ERC-3643/IERC3643ClaimTopicsRegistry.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { IERC3643TrustedIssuersRegistry } from "contracts/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ClaimIssuerTrick } from "contracts/_testContracts/ClaimIssuerTrick.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { Token } from "contracts/token/Token.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract EligibilityCheckTest is TREXFactorySetup {

    UtilityChecker public utilityChecker;
    Token public token;
    IdentityRegistry public identityRegistry;
    IERC3643ClaimTopicsRegistry public claimTopicsRegistry;
    IERC3643TrustedIssuersRegistry public trustedIssuersRegistry;
    address public tokenAgent = makeAddr("tokenAgent");
    address public claimIssuerOwner = makeAddr("claimIssuerOwner");

    // Claim issuer setup
    ClaimIssuer public claimIssuerContract;
    uint256 public claimIssuerSigningKeyPrivateKey = 0x12345;
    address public claimIssuerSigningKeyAddress = vm.addr(claimIssuerSigningKeyPrivateKey);

    function setUp() public override {
        super.setUp();

        // Deploy token suite with claim topic
        uint256 claimTopic = 1;
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = claimTopic;

        address[] memory issuers = new address[](1);
        claimIssuerContract = new ClaimIssuer(claimIssuerOwner);
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

        // Get registries
        IERC3643IdentityRegistry ir = token.identityRegistry();
        identityRegistry = IdentityRegistry(address(ir));
        claimTopicsRegistry = ir.topicsRegistry();
        trustedIssuersRegistry = ir.issuersRegistry();

        // Add tokenAgent as an agent to Token and IdentityRegistry
        vm.startPrank(deployer);
        token.addAgent(tokenAgent);
        identityRegistry.addAgent(tokenAgent);
        vm.stopPrank();

        // Add signing key to ClaimIssuer
        bytes32 signingKeyHash = keccak256(abi.encode(claimIssuerSigningKeyAddress));
        vm.prank(claimIssuerOwner);
        claimIssuerContract.addKey(signingKeyHash, 3, 1); // purpose 3 = CLAIM, keyType 1 = ECDSA

        // Register alice in IdentityRegistry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);

        // Add claim to alice's identity
        bytes memory claimData = "Some claim public data.";
        _addClaim(
            aliceIdentity, claimTopic, claimData, claimIssuerSigningKeyPrivateKey, address(claimIssuerContract), alice
        );

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

    // ============ getVerifiedDetails() Tests ============

    /// @notice Should return false when the identity is registered with topics
    function test_getVerifiedDetails_ReturnsFalse_WhenIdentityRegisteredWithTopics() public {
        // Register charlie, but we did net add claims for charlie
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(charlie, charlieIdentity, 0);

        UtilityChecker.EligibilityCheckDetails[] memory results =
            utilityChecker.getVerifiedDetails(address(token), charlie);

        assertEq(results.length, 1);
        assertEq(address(results[0].issuer), address(0));
        assertEq(results[0].topic, 0);
        assertFalse(results[0].pass);
    }

    /// @notice Should return empty result when the identity is registered without topics
    function test_getVerifiedDetails_ReturnsEmpty_WhenNoClaimTopics() public {
        // Register charlie
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(charlie, charlieIdentity, 0);

        // Remove all claim topics
        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        for (uint256 i = 0; i < topics.length; i++) {
            vm.prank(deployer);
            claimTopicsRegistry.removeClaimTopic(topics[i]);
        }

        UtilityChecker.EligibilityCheckDetails[] memory results =
            utilityChecker.getVerifiedDetails(address(token), charlie);

        assertEq(results.length, 0);
    }

    /// @notice Should return true because alice has claims
    function test_getVerifiedDetails_ReturnsTrue_AfterFixture() public {
        UtilityChecker.EligibilityCheckDetails[] memory results =
            utilityChecker.getVerifiedDetails(address(token), alice);

        assertEq(results.length, 1);
        uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
        IClaimIssuer[] memory trustedIssuers = trustedIssuersRegistry.getTrustedIssuersForClaimTopic(topics[0]);

        assertEq(address(results[0].issuer), address(trustedIssuers[0]));
        assertEq(results[0].topic, topics[0]);
        assertTrue(results[0].pass);
    }

    /// @notice Should return true for multiple issuers and topics
    function test_getVerifiedDetails_ReturnsTrue_ForMultipleIssuersAndTopics() public {
        // Deploy a new claim issuer for this test
        address newClaimIssuerOwner = makeAddr("newClaimIssuerOwner");
        ClaimIssuer newClaimIssuerContract = new ClaimIssuer(newClaimIssuerOwner);

        // Create a new signing key for the new claim issuer
        uint256 newClaimIssuerSigningKeyPrivateKey = 0x67890;
        address newClaimIssuerSigningKeyAddress = vm.addr(newClaimIssuerSigningKeyPrivateKey);

        // Add signing key to the new claim issuer
        bytes32 newSigningKeyHash = keccak256(abi.encode(newClaimIssuerSigningKeyAddress));
        vm.prank(newClaimIssuerOwner);
        newClaimIssuerContract.addKey(newSigningKeyHash, 3, 1);

        // Add two more claim topics
        uint256 claimTopic2 = 2;
        uint256 claimTopic3 = 3;

        vm.prank(deployer);
        claimTopicsRegistry.addClaimTopic(claimTopic2);
        vm.prank(deployer);
        claimTopicsRegistry.addClaimTopic(claimTopic3);

        // Add the new claim issuer for these topics
        uint256[] memory newTopics = new uint256[](2);
        newTopics[0] = claimTopic2;
        newTopics[1] = claimTopic3;
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(newClaimIssuerContract, newTopics);

        // Add claims to alice's identity for the new topics using the new claim issuer
        bytes memory claimData = "Some claim public data 2.";
        _addClaim(
            aliceIdentity,
            claimTopic2,
            claimData,
            newClaimIssuerSigningKeyPrivateKey,
            address(newClaimIssuerContract),
            alice
        );
        _addClaim(
            aliceIdentity,
            claimTopic3,
            claimData,
            newClaimIssuerSigningKeyPrivateKey,
            address(newClaimIssuerContract),
            alice
        );

        UtilityChecker.EligibilityCheckDetails[] memory results =
            utilityChecker.getVerifiedDetails(address(token), alice);

        assertEq(results.length, 3);

        uint256[] memory allTopics = claimTopicsRegistry.getClaimTopics();
        for (uint256 i = 0; i < allTopics.length; i++) {
            IClaimIssuer[] memory trustedIssuers = trustedIssuersRegistry.getTrustedIssuersForClaimTopic(allTopics[i]);
            assertEq(address(results[i].issuer), address(trustedIssuers[0]));
            assertEq(results[i].topic, allTopics[i]);
            assertTrue(results[i].pass);
        }
    }

    /// @notice Should return false when claim issuer throws an error in isClaimValid
    function test_getVerifiedDetails_ReturnsFalse_WhenClaimIssuerThrowsError() public {
        // Deploy ClaimIssuerTrick (always throws error on isClaimValid unless called by identity)
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

        // Add tricky claim (will throw error when isClaimValid is called)
        vm.prank(alice);
        aliceIdentity.addClaim(topic, 1, address(trickyClaimIssuer), "0x00", "0x00", "");

        // getVerifiedDetails should handle the error and return false
        UtilityChecker.EligibilityCheckDetails[] memory results =
            utilityChecker.getVerifiedDetails(address(token), alice);

        assertEq(results.length, 1);
        assertEq(address(results[0].issuer), address(trickyClaimIssuer));
        assertEq(results[0].topic, topic);
        assertFalse(results[0].pass); // Should be false because isClaimValid threw an error
    }

}
