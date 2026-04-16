// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { Test } from "@forge-std/Test.sol";
import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IIdentity, Identity } from "@onchain-id/solidity/contracts/Identity.sol";
import { IdFactory } from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ITREXFactory, TREXFactory } from "contracts/factory/TREXFactory.sol";
import { TREXGateway } from "contracts/factory/TREXGateway.sol";
import { AccessManagerSetupLib } from "contracts/libraries/AccessManagerSetupLib.sol";
import { RolesLib } from "contracts/libraries/RolesLib.sol";
import {
    ITREXImplementationAuthority,
    TREXImplementationAuthority
} from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { ClaimTopicsRegistry } from "contracts/registry/implementation/ClaimTopicsRegistry.sol";
import { IERC3643IdentityRegistry, IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { IdentityRegistryStorage } from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import { Token } from "contracts/token/Token.sol";

import { AccessManagerHelper } from "../../helpers/AccessManagerHelper.sol";
import { Countries } from "./Countries.sol";

contract TREXSuiteTest is Test, AccessManagerHelper {

    uint256 public constant CLAIM_TOPIC_1 = uint256(keccak256(abi.encode("CLAIM_TOPIC_1")));

    // OnchainID
    Identity public identityImplementation;
    ImplementationAuthority public implementationAuthority;
    IdFactory public idFactory;

    // Implementations
    Token tokenImplementation;
    IdentityRegistry identityRegistryImplementation;
    IdentityRegistryStorage identityRegistryStorageImplementation;
    ClaimTopicsRegistry claimTopicsRegistryImplementation;
    TrustedIssuersRegistry trustedIssuersRegistryImplementation;
    ModularCompliance modularComplianceImplementation;

    // Factories
    TREXFactory public trexFactory;
    TREXGateway public trexGateway;
    TREXImplementationAuthority public trexImplementationAuthority;

    // TREX Suite
    Token public token;
    ClaimIssuer public claimIssuer;

    // Admin roles
    address public deployer = makeAddr("deployer");
    address public agent = makeAddr("agent");

    // User roles
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public david = makeAddr("david");
    address public another = makeAddr("another");

    IIdentity public aliceIdentity;
    IIdentity public bobIdentity;
    IIdentity public charlieIdentity;

    Account public claimIssuerSigner = makeAccount("claimIssuerSigner");
    Account public aliceSigner = makeAccount("aliceSigner");
    Account public bobSigner = makeAccount("bobSigner");

    function setUp() public virtual {
        accessManager = new AccessManager(accessManagerAdmin);

        vm.startPrank(accessManagerAdmin);
        accessManager.grantRole(RolesLib.OWNER, deployer, 0);
        accessManager.grantRole(RolesLib.TOKEN_ADMIN, deployer, 0);
        accessManager.grantRole(RolesLib.SPENDING_ADMIN, deployer, 0);
        accessManager.grantRole(RolesLib.IDENTITY_ADMIN, deployer, 0);
        vm.stopPrank();

        _deployOnchainId(deployer);
        _deployImplementations();
        _deployFactories();

        vm.startPrank(accessManagerAdmin);
        AccessManagerSetupLib.setupTREXGatewayRoles(accessManager, address(trexGateway));
        AccessManagerSetupLib.setupTREXFactoryRoles(accessManager, address(trexFactory));

        accessManager.grantRole(0, address(trexFactory), 0);
        accessManager.grantRole(RolesLib.OWNER, address(trexFactory), 0);
        accessManager.grantRole(RolesLib.IDENTITY_ADMIN, address(trexFactory), 0);

        accessManager.grantRole(RolesLib.OWNER, address(trexGateway), 0);
        vm.stopPrank();

        token = _deployToken("salt", "Token", "TKN");

        _setRoles(address(this), agent);

        _deployIdentities();
        _registerIdentities(token);
    }

    function _deployOnchainId(address initialManagementKey) internal {
        vm.startPrank(deployer);
        identityImplementation = new Identity(initialManagementKey, true);
        implementationAuthority = new ImplementationAuthority(address(identityImplementation));
        idFactory = new IdFactory(address(implementationAuthority));

        claimIssuer = new ClaimIssuer(claimIssuerSigner.addr);
        vm.stopPrank();
    }

    function _deployImplementations() internal {
        tokenImplementation = new Token();
        identityRegistryImplementation = new IdentityRegistry();
        identityRegistryStorageImplementation = new IdentityRegistryStorage();
        claimTopicsRegistryImplementation = new ClaimTopicsRegistry();
        trustedIssuersRegistryImplementation = new TrustedIssuersRegistry();
        modularComplianceImplementation = new ModularCompliance();
    }

    function _deployFactories() internal {
        trexImplementationAuthority = _deployTREXImplementationAuthority(true);

        vm.startPrank(deployer);
        trexFactory = new TREXFactory(address(trexImplementationAuthority), address(idFactory), address(accessManager));
        idFactory.addTokenFactory(address(trexFactory));

        trexGateway = new TREXGateway(address(trexFactory), false, address(accessManager));

        trexImplementationAuthority.setTREXFactory(address(trexFactory));

        vm.stopPrank();
    }

    function _deployTREXImplementationAuthority(bool isReference) internal returns (TREXImplementationAuthority) {
        TREXImplementationAuthority ia =
            new TREXImplementationAuthority(isReference, address(0), address(0), address(accessManager));

        vm.prank(accessManagerAdmin);
        AccessManagerSetupLib.setupTREXImplementationAuthorityRoles(accessManager, address(ia));

        vm.prank(deployer);
        ia.addAndUseTREXVersion(
            ITREXImplementationAuthority.Version({ major: 5, minor: 0, patch: 0 }),
            ITREXImplementationAuthority.TREXContracts({
                tokenImplementation: address(tokenImplementation),
                irImplementation: address(identityRegistryImplementation),
                irsImplementation: address(identityRegistryStorageImplementation),
                ctrImplementation: address(claimTopicsRegistryImplementation),
                tirImplementation: address(trustedIssuersRegistryImplementation),
                mcImplementation: address(modularComplianceImplementation)
            })
        );

        return ia;
    }

    function _deployToken(string memory salt, string memory name, string memory symbol) internal returns (Token) {
        address[] memory agents = new address[](1);
        agents[0] = agent;

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: name,
            symbol: symbol,
            decimals: 0,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: agents,
            tokenAgents: agents,
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0),
            accessManager: address(accessManager)
        });

        ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
            claimTopics: new uint256[](0), issuers: new address[](0), issuerClaims: new uint256[][](0)
        });

        vm.prank(deployer);
        trexFactory.deployTREXSuite(salt, tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken(salt);
        vm.label(tokenAddress, symbol);

        return Token(tokenAddress);
    }

    function _deployTokenWithClaimTopic(string memory salt, string memory name, string memory symbol)
        internal
        returns (Token)
    {
        address[] memory agents = new address[](1);
        agents[0] = agent;

        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: name,
            symbol: symbol,
            decimals: 0,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: agents,
            tokenAgents: agents,
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0),
            accessManager: address(accessManager)
        });

        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        address[] memory issuers = new address[](1);
        issuers[0] = address(claimIssuer);

        uint256[][] memory issuerClaims = new uint256[][](1);
        uint256[] memory claims = new uint256[](1);
        claims[0] = CLAIM_TOPIC_1;
        issuerClaims[0] = claims;

        ITREXFactory.ClaimDetails memory claimDetails =
            ITREXFactory.ClaimDetails({ claimTopics: claimTopics, issuers: issuers, issuerClaims: issuerClaims });

        vm.prank(deployer);
        trexFactory.deployTREXSuite(salt, tokenDetails, claimDetails);

        address tokenAddress = trexFactory.getToken(salt);
        vm.label(tokenAddress, symbol);

        return Token(tokenAddress);
    }

    function getTREXContracts() public view returns (ITREXImplementationAuthority.TREXContracts memory) {
        return ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(tokenImplementation),
            ctrImplementation: address(claimTopicsRegistryImplementation),
            irImplementation: address(identityRegistryImplementation),
            irsImplementation: address(identityRegistryStorageImplementation),
            tirImplementation: address(trustedIssuersRegistryImplementation),
            mcImplementation: address(modularComplianceImplementation)
        });
    }

    function _deployIdentities() internal {
        vm.startPrank(deployer);
        aliceIdentity = IIdentity(idFactory.createIdentity(alice, "alice"));
        bobIdentity = IIdentity(idFactory.createIdentity(bob, "bob"));
        charlieIdentity = IIdentity(idFactory.createIdentity(charlie, "charlie"));
        vm.stopPrank();
    }

    function _registerIdentities(Token _token) internal {
        vm.startPrank(agent);
        IERC3643IdentityRegistry ir = _token.identityRegistry();
        ir.registerIdentity(alice, aliceIdentity, 0);
        ir.registerIdentity(bob, bobIdentity, 0);
        ir.registerIdentity(charlie, charlieIdentity, 0);
        vm.stopPrank();

        _addCountryClaim(aliceIdentity, Countries.FRANCE, alice);
        _addCountryClaim(bobIdentity, Countries.UNITED_STATES, bob);
        _addCountryClaim(charlieIdentity, Countries.SPAIN, charlie);
    }

    /// @notice Helper function to create and add a claim to an identity
    function _addClaim(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes memory _claimData,
        uint256 _signerPrivateKey,
        address _claimIssuer,
        address _caller
    ) internal {
        // Compute dataHash = keccak256(abi.encode(identity, topic, data))
        bytes32 dataHash = keccak256(abi.encode(address(_identity), _claimTopic, _claimData));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, MessageHashUtils.toEthSignedMessageHash(dataHash));
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(_caller);
        _identity.addClaim(_claimTopic, 1, _claimIssuer, signature, _claimData, "uri");
    }

    /// @notice Helper to add a country claim to an identity using the claim issuer
    function _addCountryClaim(IIdentity _identity, uint16 _country, address _wallet) internal {
        bytes memory claimData = abi.encode(_country);
        _addClaim(_identity, 2_000_008, claimData, claimIssuerSigner.key, address(claimIssuer), _wallet);
    }

    // ============ Helper Functions ============

    // Helper function to create empty TokenDetails
    function _createEmptyTokenDetails() internal view returns (ITREXFactory.TokenDetails memory) {
        return _createTokenDetails(deployer, address(0));
    }

    // Helper function to create TokenDetails with custom IRS
    function _createTokenDetails(address irs) internal view returns (ITREXFactory.TokenDetails memory) {
        return _createTokenDetails(deployer, irs);
    }

    // Helper function to create TokenDetails with custom owner and IRS
    function _createTokenDetails(address owner, address irs) internal view returns (ITREXFactory.TokenDetails memory) {
        address[] memory emptyAgents;
        address[] memory emptyModules;
        bytes[] memory emptySettings;
        return _createTokenDetails(owner, irs, emptyAgents, emptyAgents, emptyModules, emptySettings);
    }

    // Helper function to create TokenDetails with all custom parameters
    function _createTokenDetails(
        address owner,
        address irs,
        address[] memory irAgents,
        address[] memory tokenAgents,
        address[] memory complianceModules,
        bytes[] memory complianceSettings
    ) internal view returns (ITREXFactory.TokenDetails memory) {
        return ITREXFactory.TokenDetails({
            owner: owner,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: irs,
            ONCHAINID: address(0),
            irAgents: irAgents,
            tokenAgents: tokenAgents,
            complianceModules: complianceModules,
            complianceSettings: complianceSettings,
            accessManager: address(accessManager)
        });
    }

    // Helper function to create empty ClaimDetails
    function _createEmptyClaimDetails() internal pure returns (ITREXFactory.ClaimDetails memory) {
        uint256[] memory emptyTopics;
        address[] memory emptyIssuers;
        uint256[][] memory emptyClaims;

        return ITREXFactory.ClaimDetails({ claimTopics: emptyTopics, issuers: emptyIssuers, issuerClaims: emptyClaims });
    }

}
