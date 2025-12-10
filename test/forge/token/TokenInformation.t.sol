// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IdentityProxy } from "@onchain-id/solidity/contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Paused, Unpaused, UpdatedTokenInformation } from "contracts/ERC-3643/IERC3643.sol";
import { EmptyString } from "contracts/errors/InvalidArgumentErrors.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { ModularComplianceProxy } from "contracts/proxy/ModularComplianceProxy.sol";
import {
    AgentNotAuthorized,
    AmountAboveFrozenTokens,
    CallerDoesNotHaveAgentRole,
    ERC20InsufficientBalance,
    EnforcedPause,
    ExpectedPause
} from "contracts/token/Token.sol";
import { Token } from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { TREXFactorySetup } from "test/forge/helpers/TREXFactorySetup.sol";

contract TokenInformationTest is TREXFactorySetup {

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

        // Unpause token
        vm.prank(tokenAgent);
        token.unpause();
    }

    // ============ setName() Tests ============

    /// @notice Should revert when called by not owner
    function test_setName_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setName("My Token");
    }

    /// @notice Should revert when the name is empty
    function test_setName_RevertWhen_EmptyString() public {
        vm.prank(deployer);
        vm.expectRevert(EmptyString.selector);
        token.setName("");
    }

    /// @notice Should set the name
    function test_setName_Success() public {
        string memory newName = "Updated Test Token";
        string memory currentSymbol = token.symbol();
        uint8 currentDecimals = token.decimals();
        string memory currentVersion = token.version();
        address currentOnchainID = token.onchainID();

        vm.prank(deployer);
        token.setName(newName);

        assertEq(keccak256(bytes(token.name())), keccak256(bytes(newName)), "Token name should match");
    }

    // ============ setSymbol() Tests ============

    /// @notice Should revert when called by not owner
    function test_setSymbol_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setSymbol("UpdtTK");
    }

    /// @notice Should revert when the symbol is empty
    function test_setSymbol_RevertWhen_EmptyString() public {
        vm.prank(deployer);
        vm.expectRevert(EmptyString.selector);
        token.setSymbol("");
    }

    /// @notice Should set the symbol
    function test_setSymbol_Success() public {
        string memory newSymbol = "UpdtTK";

        vm.prank(deployer);
        token.setSymbol(newSymbol);

        assertEq(keccak256(bytes(token.symbol())), keccak256(bytes(newSymbol)), "Token symbol should match");
    }

    // ============ setOnchainID() Tests ============

    /// @notice Should revert when called by not owner
    function test_setOnchainID_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setOnchainID(address(0));
    }

    /// @notice Should set the onchainID
    function test_setOnchainID_Success() public {
        // Create an identity using the helper
        ImplementationAuthority identityImplementationAuthority =
            ImplementationAuthority(onchainidSetup.idFactory.implementationAuthority());
        IIdentity newIdentity =
            IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), deployer)));

        vm.prank(deployer);
        token.setOnchainID(address(newIdentity));

        assertEq(token.onchainID(), address(newIdentity));
    }

    // ============ setIdentityRegistry() Tests ============

    /// @notice Should revert when called by not owner
    function test_setIdentityRegistry_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setIdentityRegistry(address(0));
    }

    // ============ totalSupply() Tests ============

    /// @notice Should return the total supply
    function test_totalSupply_ReturnsTotalSupply() public view {
        // Token starts with zero total supply
        assertEq(token.totalSupply(), 0);
    }

    // ============ setCompliance() Tests ============

    /// @notice Should revert when called by not owner
    function test_setCompliance_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        token.setCompliance(address(0));
    }

    // ============ compliance() Tests ============

    /// @notice Should return the compliance address
    function test_compliance_ReturnsComplianceAddress() public {
        // Deploy ModularCompliance proxy (similar to deploySuiteWithModularCompliancesFixture)
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        // Transfer ownership to deployer (compliance is owned by test contract after deployment)
        vm.prank(address(this));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        // Set compliance
        vm.prank(deployer);
        token.setCompliance(address(complianceProxy));

        assertEq(address(token.compliance()), address(complianceProxy));
    }

    // ============ pause() Tests ============

    /// @notice Should revert when the caller is not an agent
    function test_pause_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.pause();
    }

    /// @notice Should revert when agent permission is restricted
    function test_pause_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: true
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "pause disabled"));
        token.pause();
    }

    /// @notice Should pause the token when not paused
    function test_pause_Success() public {
        vm.prank(tokenAgent);
        token.pause();

        assertTrue(token.paused());
    }

    /// @notice Should revert when the token is already paused
    function test_pause_RevertWhen_AlreadyPaused() public {
        // First pause
        vm.prank(tokenAgent);
        token.pause();

        // Try to pause again
        vm.prank(tokenAgent);
        vm.expectRevert(EnforcedPause.selector);
        token.pause();
    }

    // ============ unpause() Tests ============

    /// @notice Should revert when the caller is not an agent
    function test_unpause_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.unpause();
    }

    /// @notice Should revert when agent permission is restricted
    function test_unpause_RevertWhen_AgentRestricted() public {
        // First pause
        vm.prank(tokenAgent);
        token.pause();

        // Set restrictions
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: true
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "pause disabled"));
        token.unpause();
    }

    /// @notice Should unpause the token when paused
    function test_unpause_Success() public {
        // First pause
        vm.prank(tokenAgent);
        token.pause();

        // Unpause
        vm.prank(tokenAgent);
        token.unpause();

        assertFalse(token.paused());
    }

    /// @notice Should revert when the token is not paused
    function test_unpause_RevertWhen_NotPaused() public {
        vm.prank(tokenAgent);
        vm.expectRevert(ExpectedPause.selector);
        token.unpause();
    }

    // ============ setAddressFrozen() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_setAddressFrozen_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.setAddressFrozen(another, true);
    }

    // ============ freezePartialTokens() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_freezePartialTokens_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.freezePartialTokens(another, 1);
    }

    /// @notice Should revert when amounts exceed current balance
    function test_freezePartialTokens_RevertWhen_AmountExceedsBalance() public {
        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, another, 0, 1));
        token.freezePartialTokens(another, 1);
    }

    // ============ unfreezePartialTokens() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_unfreezePartialTokens_RevertWhen_NotAgent() public {
        vm.prank(another);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.unfreezePartialTokens(another, 1);
    }

    /// @notice Should revert when amounts exceed current frozen balance
    function test_unfreezePartialTokens_RevertWhen_AmountExceedsFrozen() public {
        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AmountAboveFrozenTokens.selector, 1, 0));
        token.unfreezePartialTokens(another, 1);
    }

    // ============ supportsInterface() Tests ============

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(token.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IERC20 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC20() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC20InterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IToken interface ID
    function test_supportsInterface_ReturnsTrue_ForIToken() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getITokenInterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC3643 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC3643() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC3643InterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC20Permit interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC20Permit() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC20PermitInterfaceId();
        assertTrue(token.supportsInterface(interfaceId));
    }

}
