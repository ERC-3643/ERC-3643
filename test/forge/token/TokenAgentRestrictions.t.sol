// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IToken } from "contracts/token/IToken.sol";
import { Token } from "contracts/token/Token.sol";
import { AddressNotAgent } from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { TREXFactorySetup } from "test/forge/helpers/TREXFactorySetup.sol";

contract TokenAgentRestrictionsTest is TREXFactorySetup {

    // Event declaration for expectEmit
    event AgentRestrictionsSet(
        address indexed _agent,
        bool _disableMint,
        bool _disableBurn,
        bool _disableAddressFreeze,
        bool _disableForceTransfer,
        bool _disablePartialFreeze,
        bool _disablePause,
        bool _disableRecovery
    );

    // Token suite deployed in setUp()
    address public tokenAddress;
    Token public token;

    // Additional test addresses
    address public tokenAgent = makeAddr("tokenAgent");

    function setUp() public override {
        super.setUp();

        // Deploy token suite
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
        ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
            claimTopics: new uint256[](0), issuers: new address[](0), issuerClaims: new uint256[][](0)
        });

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        tokenAddress = trexFactory.getToken("salt");
        token = Token(tokenAddress);

        // Add tokenAgent as an agent
        vm.prank(deployer);
        token.addAgent(tokenAgent);
    }

    // ============ setAgentRestrictions() Tests ============

    /// @notice Should revert when called by not owner
    function test_setAgentRestrictions_RevertWhen_NotOwner() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setAgentRestrictions(tokenAgent, restrictions);
    }

    /// @notice Should revert when the given address is not an agent
    function test_setAgentRestrictions_RevertWhen_AddressNotAgent() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAgent.selector, another));
        token.setAgentRestrictions(another, restrictions);
    }

    /// @notice Should set restrictions when the given address is an agent
    function test_setAgentRestrictions_Success() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        vm.prank(deployer);
        vm.expectEmit(true, false, false, false);
        emit AgentRestrictionsSet(tokenAgent, true, true, true, true, true, true, true);
        token.setAgentRestrictions(tokenAgent, restrictions); // agent already added in the setup above
    }

    // ============ getAgentRestrictions() Tests ============

    /// @notice Should return restrictions after they are set
    function test_getAgentRestrictions_ReturnsRestrictions() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: true,
            disablePartialFreeze: true,
            disableAddressFreeze: true,
            disableRecovery: true,
            disableForceTransfer: true,
            disablePause: true
        });

        // Set restrictions
        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        // Get restrictions
        TokenRoles memory retrieved = token.getAgentRestrictions(tokenAgent);

        // Verify all restrictions are set correctly
        assertTrue(retrieved.disableAddressFreeze, "disableAddressFreeze should be true");
        assertTrue(retrieved.disableBurn, "disableBurn should be true");
        assertTrue(retrieved.disableForceTransfer, "disableForceTransfer should be true");
        assertTrue(retrieved.disableMint, "disableMint should be true");
        assertTrue(retrieved.disablePartialFreeze, "disablePartialFreeze should be true");
        assertTrue(retrieved.disablePause, "disablePause should be true");
        assertTrue(retrieved.disableRecovery, "disableRecovery should be true");
    }

}
