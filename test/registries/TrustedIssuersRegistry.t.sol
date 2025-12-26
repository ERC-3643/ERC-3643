// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ClaimIssuer } from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    ClaimTopicsUpdated,
    TrustedIssuerAdded,
    TrustedIssuerRemoved
} from "contracts/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { MockContract } from "contracts/_testContracts/MockContract.sol";
import { InitializationFailed } from "contracts/errors/CommonErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { TrustedIssuersRegistryProxy } from "contracts/proxy/TrustedIssuersRegistryProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import {
    ClaimTopicsCannotBeEmpty,
    MaxClaimTopcisReached,
    MaxTrustedIssuersReached,
    NotATrustedIssuer,
    TrustedClaimTopicsCannotBeEmpty,
    TrustedIssuerAlreadyExists,
    TrustedIssuerDoesNotExist
} from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { Test } from "forge-std/Test.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";

contract TrustedIssuersRegistryTest is Test {

    // Contracts
    TrustedIssuersRegistry public trustedIssuersRegistry;
    TREXImplementationAuthority public implementationAuthority;
    ClaimIssuer public claimIssuerContract;

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public another = makeAddr("another");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public claimIssuer = makeAddr("claimIssuer");

    // Claim topics
    uint256 public constant CLAIM_TOPIC_1 = 10;
    uint256 public constant CLAIM_TOPIC_2 = 42;
    uint256 public constant CLAIM_TOPIC_3 = 66;
    uint256 public constant CLAIM_TOPIC_4 = 100;

    /// @notice Sets up TrustedIssuersRegistry via proxy
    function setUp() public {
        // Deploy Implementation Authority with all implementations
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory iaSetup =
            ImplementationAuthorityHelper.deploy(true);
        implementationAuthority = iaSetup.implementationAuthority;

        // Transfer ownership to deployer
        Ownable(address(implementationAuthority)).transferOwnership(deployer);

        // Deploy TrustedIssuersRegistryProxy
        TrustedIssuersRegistryProxy proxy = new TrustedIssuersRegistryProxy(address(implementationAuthority));
        trustedIssuersRegistry = TrustedIssuersRegistry(address(proxy));

        // Transfer ownership to deployer
        trustedIssuersRegistry.transferOwnership(deployer);

        // Deploy ClaimIssuer (from ONCHAINID)
        claimIssuerContract = new ClaimIssuer(claimIssuer);

        // Add the ClaimIssuer as a trusted issuer with a claim topic
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(claimIssuerContract, claimTopics);
    }

    // ============ addTrustedIssuer() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_addTrustedIssuer_RevertWhen_NotOwner() public {
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        ClaimIssuer anotherClaimIssuer = new ClaimIssuer(another);
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        trustedIssuersRegistry.addTrustedIssuer(anotherClaimIssuer, claimTopics);
    }

    /// @notice Should revert when issuer to add is zero address
    function test_addTrustedIssuer_RevertWhen_ZeroAddress() public {
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        trustedIssuersRegistry.addTrustedIssuer(ClaimIssuer(address(0)), claimTopics);
    }

    /// @notice Should revert when issuer is already registered
    function test_addTrustedIssuer_RevertWhen_AlreadyRegistered() public {
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        vm.expectRevert(TrustedIssuerAlreadyExists.selector);
        trustedIssuersRegistry.addTrustedIssuer(claimIssuerContract, claimTopics);
    }

    /// @notice Should revert when claim topics array is empty
    function test_addTrustedIssuer_RevertWhen_ClaimTopicsEmpty() public {
        ClaimIssuer newClaimIssuer = new ClaimIssuer(bob);
        uint256[] memory emptyClaimTopics = new uint256[](0);

        vm.prank(deployer);
        vm.expectRevert(TrustedClaimTopicsCannotBeEmpty.selector);
        trustedIssuersRegistry.addTrustedIssuer(newClaimIssuer, emptyClaimTopics);
    }

    /// @notice Should revert when claim topics array exceeds 15 topics
    function test_addTrustedIssuer_RevertWhen_MoreThan15ClaimTopics() public {
        ClaimIssuer newClaimIssuer = new ClaimIssuer(bob);
        uint256[] memory claimTopics = new uint256[](16); // 16 topics > 15
        for (uint256 i = 0; i < 16; i++) {
            claimTopics[i] = i;
        }

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxClaimTopcisReached.selector, 15));
        trustedIssuersRegistry.addTrustedIssuer(newClaimIssuer, claimTopics);
    }

    /// @notice Should revert when there are already 49 trusted issuers
    function test_addTrustedIssuer_RevertWhen_MoreThan49Issuers() public {
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        // Add 49 more issuers (we already have 1 from setUp, so 49 more to reach 50 total)
        // Contract allows up to 50 issuers (length < 50 means 0-49, allowing 50 total)
        // After adding 49 more, we'll have 50 total, then trying to add 51st should fail
        for (uint256 i = 0; i < 49; i++) {
            address issuerAddress = address(uint160(uint256(keccak256(abi.encodePacked("issuer", i)))));
            ClaimIssuer newClaimIssuer = new ClaimIssuer(issuerAddress);
            vm.prank(deployer);
            trustedIssuersRegistry.addTrustedIssuer(newClaimIssuer, claimTopics);
        }

        // Try to add 51st issuer (50 already exist, so this should fail)
        ClaimIssuer fiftyFirstClaimIssuer = new ClaimIssuer(another);
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxTrustedIssuersReached.selector, 50));
        trustedIssuersRegistry.addTrustedIssuer(fiftyFirstClaimIssuer, claimTopics);
    }

    // ============ removeTrustedIssuer() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_removeTrustedIssuer_RevertWhen_NotOwner() public {
        ClaimIssuer anotherClaimIssuerForRemove = new ClaimIssuer(another);

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        trustedIssuersRegistry.removeTrustedIssuer(anotherClaimIssuerForRemove);
    }

    /// @notice Should revert when issuer to remove is zero address
    function test_removeTrustedIssuer_RevertWhen_ZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        trustedIssuersRegistry.removeTrustedIssuer(ClaimIssuer(address(0)));
    }

    /// @notice Should revert when issuer is not registered
    function test_removeTrustedIssuer_RevertWhen_NotRegistered() public {
        ClaimIssuer newClaimIssuer = new ClaimIssuer(deployer);

        vm.prank(deployer);
        vm.expectRevert(NotATrustedIssuer.selector);
        trustedIssuersRegistry.removeTrustedIssuer(newClaimIssuer);
    }

    /// @notice Should remove the issuer from trusted list
    function test_removeTrustedIssuer_Success() public {
        // Add more issuers first
        ClaimIssuer bobClaimIssuer = new ClaimIssuer(bob);
        ClaimIssuer anotherClaimIssuer = new ClaimIssuer(another);
        ClaimIssuer charlieClaimIssuer = new ClaimIssuer(charlie);

        uint256[] memory topicsBob = new uint256[](3);
        topicsBob[0] = CLAIM_TOPIC_3;
        topicsBob[1] = CLAIM_TOPIC_4;
        topicsBob[2] = CLAIM_TOPIC_1;

        uint256[] memory topicsAnother = new uint256[](2);
        topicsAnother[0] = CLAIM_TOPIC_1;
        topicsAnother[1] = CLAIM_TOPIC_2;

        uint256[] memory topicsCharlie = new uint256[](3);
        topicsCharlie[0] = CLAIM_TOPIC_2;
        topicsCharlie[1] = CLAIM_TOPIC_3;
        topicsCharlie[2] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(bobClaimIssuer, topicsBob);
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(anotherClaimIssuer, topicsAnother);
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(charlieClaimIssuer, topicsCharlie);

        // Verify another is trusted
        assertTrue(trustedIssuersRegistry.isTrustedIssuer(address(anotherClaimIssuer)));

        // Remove another
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit TrustedIssuerRemoved(IClaimIssuer(address(anotherClaimIssuer)));
        trustedIssuersRegistry.removeTrustedIssuer(anotherClaimIssuer);

        // Verify another is no longer trusted
        assertFalse(trustedIssuersRegistry.isTrustedIssuer(address(anotherClaimIssuer)));

        // Verify remaining issuers
        IClaimIssuer[] memory trustedIssuers = trustedIssuersRegistry.getTrustedIssuers();

        // remember that in setup we already added claimIssuerContract to trusted issuer
        assertEq(trustedIssuers.length, 3);
        assertEq(address(trustedIssuers[0]), address(claimIssuerContract));
        assertEq(address(trustedIssuers[1]), address(bobClaimIssuer));
        assertEq(address(trustedIssuers[2]), address(charlieClaimIssuer));
    }

    // ============ updateIssuerClaimTopics() Tests ============

    /// @notice Should revert when sender is not the owner
    function test_updateIssuerClaimTopics_RevertWhen_NotOwner() public {
        ClaimIssuer anotherClaimIssuerForUpdate = new ClaimIssuer(another);
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        trustedIssuersRegistry.updateIssuerClaimTopics(anotherClaimIssuerForUpdate, claimTopics);
    }

    /// @notice Should revert when issuer to update is zero address
    function test_updateIssuerClaimTopics_RevertWhen_ZeroAddress() public {
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        trustedIssuersRegistry.updateIssuerClaimTopics(ClaimIssuer(address(0)), claimTopics);
    }

    /// @notice Should revert when issuer is not registered
    function test_updateIssuerClaimTopics_RevertWhen_NotRegistered() public {
        ClaimIssuer newClaimIssuer = new ClaimIssuer(deployer);
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        vm.expectRevert(NotATrustedIssuer.selector);
        trustedIssuersRegistry.updateIssuerClaimTopics(newClaimIssuer, claimTopics);
    }

    /// @notice Should revert when claim topics array have more than 15 elements
    function test_updateIssuerClaimTopics_RevertWhen_MoreThan15ClaimTopics() public {
        uint256[] memory claimTopics = new uint256[](16); // 16 topics > 15
        for (uint256 i = 0; i < 16; i++) {
            claimTopics[i] = i;
        }

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxClaimTopcisReached.selector, 15));
        trustedIssuersRegistry.updateIssuerClaimTopics(claimIssuerContract, claimTopics);
    }

    /// @notice Should revert when claim topics array is empty
    function test_updateIssuerClaimTopics_RevertWhen_ClaimTopicsEmpty() public {
        uint256[] memory emptyClaimTopics = new uint256[](0);

        vm.prank(deployer);
        vm.expectRevert(ClaimTopicsCannotBeEmpty.selector);
        trustedIssuersRegistry.updateIssuerClaimTopics(claimIssuerContract, emptyClaimTopics);
    }

    /// @notice Should update the topics of the trusted issuers
    function test_updateIssuerClaimTopics_Success() public {
        // Get initial claim topics
        uint256[] memory initialTopics = trustedIssuersRegistry.getTrustedIssuerClaimTopics(claimIssuerContract);
        // remember in the setup function we added CLAIM_TOPIC_1 to the claimIssuerContract
        assertGt(initialTopics.length, 0);

        uint256[] memory newTopics = new uint256[](2);
        newTopics[0] = CLAIM_TOPIC_3;
        newTopics[1] = CLAIM_TOPIC_4;

        // Update claim topics
        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ClaimTopicsUpdated(IClaimIssuer(address(claimIssuerContract)), newTopics);
        trustedIssuersRegistry.updateIssuerClaimTopics(claimIssuerContract, newTopics);

        // Verify new topics are set
        assertTrue(trustedIssuersRegistry.hasClaimTopic(address(claimIssuerContract), CLAIM_TOPIC_3));
        assertTrue(trustedIssuersRegistry.hasClaimTopic(address(claimIssuerContract), CLAIM_TOPIC_4));
        // CLAIM_TOPIC_1 that was set in the setup method is no more there
        assertFalse(trustedIssuersRegistry.hasClaimTopic(address(claimIssuerContract), initialTopics[0]));

        // Verify getter returns new topics
        uint256[] memory retrievedTopics = trustedIssuersRegistry.getTrustedIssuerClaimTopics(claimIssuerContract);
        assertEq(retrievedTopics.length, 2);
        assertEq(retrievedTopics[0], CLAIM_TOPIC_3);
        assertEq(retrievedTopics[1], CLAIM_TOPIC_4);
    }

    /// @notice Covers inner loop increment when issuer is not first in claimTopic array
    function test_updateIssuerClaimTopics_CoversInnerLoopIncrement() public {
        // Add two more issuers with the same initial claim topic to ensure the
        // issuer being updated is not at index 0 in the claimTopic array
        ClaimIssuer firstIssuer = new ClaimIssuer(bob);
        ClaimIssuer secondIssuer = new ClaimIssuer(another);

        uint256[] memory topics = new uint256[](1);
        topics[0] = CLAIM_TOPIC_1;

        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(firstIssuer, topics);
        vm.prank(deployer);
        trustedIssuersRegistry.addTrustedIssuer(secondIssuer, topics);

        // Update claim topics for the secondIssuer so the inner loop iterates past index 0
        uint256[] memory newTopics = new uint256[](1);
        newTopics[0] = CLAIM_TOPIC_2;

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit ClaimTopicsUpdated(IClaimIssuer(address(secondIssuer)), newTopics);
        trustedIssuersRegistry.updateIssuerClaimTopics(secondIssuer, newTopics);

        // Verify mapping updated: no longer associated with CLAIM_TOPIC_1 and now mapped to CLAIM_TOPIC_2
        assertFalse(trustedIssuersRegistry.hasClaimTopic(address(secondIssuer), CLAIM_TOPIC_1));
        assertTrue(trustedIssuersRegistry.hasClaimTopic(address(secondIssuer), CLAIM_TOPIC_2));
    }

    // ============ getTrustedIssuerClaimTopics() Tests ============

    /// @notice Should revert when issuer is not registered
    function test_getTrustedIssuerClaimTopics_RevertWhen_NotRegistered() public {
        ClaimIssuer newClaimIssuer = new ClaimIssuer(deployer);
        vm.prank(deployer);
        vm.expectRevert(TrustedIssuerDoesNotExist.selector);
        trustedIssuersRegistry.getTrustedIssuerClaimTopics(newClaimIssuer);
    }

    // ============ supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(trustedIssuersRegistry.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IERC3643TrustedIssuersRegistry interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC3643TrustedIssuersRegistry() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC3643TrustedIssuersRegistryInterfaceId();
        assertTrue(trustedIssuersRegistry.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(trustedIssuersRegistry.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(trustedIssuersRegistry.supportsInterface(interfaceId));
    }

    // ============ Constructor Tests ============

    /// @notice Should revert when implementation authority is zero address
    function test_constructor_RevertWhen_ImplementationAuthorityZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new TrustedIssuersRegistryProxy(address(0));
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid TIR implementation
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));

        // Create a version with invalid TIR implementation (mock contract without init())
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(mockImpl), // Invalid - doesn't have proper init
            ctrImplementation: address(mockImpl), // Invalid
            irImplementation: address(mockImpl), // Invalid
            irsImplementation: address(mockImpl), // Invalid
            tirImplementation: address(mockImpl), // Invalid - doesn't have init() function
            mcImplementation: address(mockImpl) // Invalid
        });

        // Add version to IA (need to be owner)
        Ownable(address(incompleteIA)).transferOwnership(deployer);
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        vm.expectRevert(InitializationFailed.selector);
        new TrustedIssuersRegistryProxy(address(incompleteIA));
    }

}
