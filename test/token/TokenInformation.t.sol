// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    AddressFrozen,
    Paused,
    TokensFrozen,
    TokensUnfrozen,
    Unpaused,
    UpdatedTokenInformation
} from "contracts/ERC-3643/IERC3643.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { MockContract } from "contracts/_testContracts/MockContract.sol";
import { TestTokenInternal } from "contracts/_testContracts/TestTokenInternal.sol";
import {
    ERC20InvalidReceiver,
    ERC20InvalidSender,
    ERC20InvalidSpender,
    InitializationFailed
} from "contracts/errors/CommonErrors.sol";
import { DecimalsOutOfRange, EmptyString, ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { ModularComplianceProxy } from "contracts/proxy/ModularComplianceProxy.sol";
import { TokenProxy } from "contracts/proxy/TokenProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { AlreadyInitialized } from "contracts/token/Token.sol";
import {
    AgentNotAuthorized,
    AmountAboveFrozenTokens,
    CallerDoesNotHaveAgentRole,
    ERC20InsufficientBalance,
    EnforcedPause,
    ExpectedPause,
    Token
} from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { TokenTestBase } from "test/token/TokenTestBase.sol";

contract TokenInformationTest is TokenTestBase {

    // Token suite components
    IdentityRegistry public identityRegistry;

    function setUp() public override {
        super.setUp();

        // Get IdentityRegistry
        IERC3643IdentityRegistry ir = token.identityRegistry();
        identityRegistry = IdentityRegistry(address(ir));

        // Add tokenAgent as an agent
        vm.startPrank(deployer);
        token.addAgent(tokenAgent);
        identityRegistry.addAgent(tokenAgent);
        vm.stopPrank();

        // Register alice and bob in IdentityRegistry
        vm.startPrank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);
        vm.stopPrank();

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
        // create an identity using IdFactory
        vm.startPrank(deployer);
        IIdentity newIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(deployer, "deployer-salt"));
        token.setOnchainID(address(newIdentity));
        vm.stopPrank();

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
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        // Set compliance
        vm.prank(deployer);
        token.setCompliance(address(complianceProxy));

        assertEq(address(token.compliance()), address(complianceProxy));
    }

    /// @notice Should unbind existing compliance when setting new compliance
    function test_setCompliance_UnbindsExistingCompliance() public {
        // Deploy first compliance
        ModularComplianceProxy complianceProxy1 = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy1)).transferOwnership(deployer);

        // Deploy second compliance
        ModularComplianceProxy complianceProxy2 = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy2)).transferOwnership(deployer);

        // Set first compliance
        vm.prank(deployer);
        token.setCompliance(address(complianceProxy1));
        assertEq(address(token.compliance()), address(complianceProxy1));

        // Set second compliance (should unbind first)
        vm.prank(deployer);
        token.setCompliance(address(complianceProxy2));
        assertEq(address(token.compliance()), address(complianceProxy2));
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

    /// @notice Should revert when agent permission is restricted
    function test_setAddressFrozen_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: true,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "address freeze disabled"));
        token.setAddressFrozen(alice, true);
    }

    /// @notice Should freeze address successfully
    function test_setAddressFrozen_Success() public {
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit AddressFrozen(alice, true, tokenAgent);
        token.setAddressFrozen(alice, true);

        assertTrue(token.isFrozen(alice));
    }

    /// @notice Should unfreeze address successfully
    function test_setAddressFrozen_UnfreezeSuccess() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(alice, true);

        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit AddressFrozen(alice, false, tokenAgent);
        token.setAddressFrozen(alice, false);

        assertFalse(token.isFrozen(alice));
    }

    // ============ freezePartialTokens() Tests ============

    /// @notice Should revert when amounts exceed current balance
    function test_freezePartialTokens_RevertWhen_AmountExceedsBalance() public {
        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, another, 0, 1));
        token.freezePartialTokens(another, 1);
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

    // ============ batchSetAddressFrozen() Tests ============

    /// @notice Should perform batch address freezing
    function test_batchSetAddressFrozen_Success() public {
        address[] memory userAddresses = new address[](2);
        userAddresses[0] = alice;
        userAddresses[1] = bob;
        bool[] memory freeze = new bool[](2);
        freeze[0] = true;
        freeze[1] = true;

        vm.prank(tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit AddressFrozen(alice, true, tokenAgent);
        vm.expectEmit(true, true, true, false, address(token));
        emit AddressFrozen(bob, true, tokenAgent);
        token.batchSetAddressFrozen(userAddresses, freeze);

        assertTrue(token.isFrozen(alice));
        assertTrue(token.isFrozen(bob));
    }

    // ============ batchFreezePartialTokens() Tests ============

    /// @notice Should perform batch partial token freezing
    function test_batchFreezePartialTokens_Success() public {
        // Ensure users have balances
        vm.prank(tokenAgent);
        token.mint(alice, 1000);
        vm.prank(tokenAgent);
        token.mint(bob, 500);

        address[] memory userAddresses = new address[](2);
        userAddresses[0] = alice;
        userAddresses[1] = bob;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(tokenAgent);
        token.batchFreezePartialTokens(userAddresses, amounts);

        assertEq(token.getFrozenTokens(alice), 100);
        assertEq(token.getFrozenTokens(bob), 200);
    }

    // ============ batchUnfreezePartialTokens() Tests ============

    /// @notice Should perform batch partial token unfreezing
    function test_batchUnfreezePartialTokens_Success() public {
        // Ensure users have balances
        vm.prank(tokenAgent);
        token.mint(alice, 1000);
        vm.prank(tokenAgent);
        token.mint(bob, 500);

        // First freeze tokens
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, 200);
        vm.prank(tokenAgent);
        token.freezePartialTokens(bob, 300);

        address[] memory userAddresses = new address[](2);
        userAddresses[0] = alice;
        userAddresses[1] = bob;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(tokenAgent);
        token.batchUnfreezePartialTokens(userAddresses, amounts);

        assertEq(token.getFrozenTokens(alice), 100);
        assertEq(token.getFrozenTokens(bob), 100);
    }

    // ============ Constructor Tests ============

    /// @notice Should prevent direct initialization of Token implementation
    function test_constructor_CallsDisableInitializers() public {
        Token tokenImplementation = new Token();
        assertTrue(address(tokenImplementation) != address(0));

        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        tokenImplementation.init(
            address(identityRegistry), address(complianceProxy), "Test Token", "TEST", 18, address(0)
        );
    }

    /// @notice Should revert when implementation authority is zero address
    function test_TokenProxy_constructor_RevertWhen_ImplementationAuthorityZeroAddress() public {
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new TokenProxy(address(0), randomAddress, randomAddress, "Test", "TST", 18, address(0));
    }

    /// @notice Should revert when identity registry is zero address
    function test_TokenProxy_constructor_RevertWhen_IdentityRegistryZeroAddress() public {
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new TokenProxy(
            address(getTREXImplementationAuthority()), address(0), randomAddress, "Test", "TST", 18, address(0)
        );
    }

    /// @notice Should revert when compliance is zero address
    function test_TokenProxy_constructor_RevertWhen_ComplianceZeroAddress() public {
        address randomAddress = vm.addr(999);
        vm.expectRevert(ZeroAddress.selector);
        new TokenProxy(
            address(getTREXImplementationAuthority()), randomAddress, address(0), "Test", "TST", 18, address(0)
        );
    }

    /// @notice Should revert when name is empty string
    function test_TokenProxy_constructor_RevertWhen_NameEmpty() public {
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        address randomAddress = vm.addr(999);
        vm.expectRevert(EmptyString.selector);
        new TokenProxy(
            address(getTREXImplementationAuthority()),
            randomAddress,
            address(complianceProxy),
            "",
            "TST",
            18,
            address(0)
        );
    }

    /// @notice Should revert when symbol is empty string
    function test_TokenProxy_constructor_RevertWhen_SymbolEmpty() public {
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        address randomAddress = vm.addr(999);
        vm.expectRevert(EmptyString.selector);
        new TokenProxy(
            address(getTREXImplementationAuthority()),
            randomAddress,
            address(complianceProxy),
            "Test",
            "",
            18,
            address(0)
        );
    }

    /// @notice Should revert when decimals is greater than 18
    function test_TokenProxy_constructor_RevertWhen_DecimalsGreaterThan18() public {
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        address randomAddress = vm.addr(999);
        vm.expectRevert(abi.encodeWithSelector(DecimalsOutOfRange.selector, 19));
        new TokenProxy(
            address(getTREXImplementationAuthority()),
            randomAddress,
            address(complianceProxy),
            "Test",
            "TST",
            19,
            address(0)
        );
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_TokenProxy_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid Token implementation
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));

        // Create a version with invalid Token implementation (mock contract without init())
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(mockImpl), // Invalid - doesn't have init() function
            ctrImplementation: address(mockImpl), // Invalid
            irImplementation: address(mockImpl), // Invalid
            irsImplementation: address(mockImpl), // Invalid
            tirImplementation: address(mockImpl), // Invalid
            mcImplementation: address(mockImpl) // Invalid
        });

        // Add version to IA (need to be owner)
        Ownable(address(incompleteIA)).transferOwnership(deployer);
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        address randomAddress = vm.addr(999);
        vm.expectRevert(InitializationFailed.selector);
        new TokenProxy(address(incompleteIA), randomAddress, address(complianceProxy), "Test", "TST", 18, address(0));
    }

    // ============ Token.init() Tests ============

    function test_init_RevertWhen_IdentityRegistryZeroAddress_DirectCall() public {
        // Deploy new implementation
        Token implementation = new Token();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        vm.expectRevert(ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Token.init.selector,
                address(0), // Zero address for Identity Registry
                address(complianceProxy),
                "Test Token",
                "TEST",
                18,
                address(0)
            )
        );
    }

    function test_init_RevertWhen_ComplianceZeroAddress_DirectCall() public {
        // Deploy new implementation
        Token implementation = new Token();
        address randomAddress = vm.addr(999);

        vm.expectRevert(ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Token.init.selector,
                randomAddress,
                address(0), // Zero address for Compliance
                "Test Token",
                "TEST",
                18,
                address(0)
            )
        );
    }

    function test_init_RevertWhen_NameEmpty_DirectCall() public {
        // Deploy new implementation
        Token implementation = new Token();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);
        address randomAddress = vm.addr(999);

        vm.expectRevert(EmptyString.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Token.init.selector,
                randomAddress,
                address(complianceProxy),
                "", // Empty name
                "TEST",
                18,
                address(0)
            )
        );
    }

    function test_init_RevertWhen_SymbolEmpty_DirectCall() public {
        // Deploy new implementation
        Token implementation = new Token();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);
        address randomAddress = vm.addr(999);

        vm.expectRevert(EmptyString.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Token.init.selector,
                randomAddress,
                address(complianceProxy),
                "Test Token",
                "", // Empty symbol
                18,
                address(0)
            )
        );
    }

    function test_init_RevertWhen_DecimalsGreaterThan18_DirectCall() public {
        // Deploy new implementation
        Token implementation = new Token();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);
        address randomAddress = vm.addr(999);

        vm.expectRevert(abi.encodeWithSelector(DecimalsOutOfRange.selector, 19));
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Token.init.selector,
                randomAddress,
                address(complianceProxy),
                "Test Token",
                "TEST",
                19, // Decimals > 18
                address(0)
            )
        );
    }

    function test_init_RevertWhen_AlreadyInitialized_OwnerNotZero() public {
        Token implementation = new Token();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);
        address randomAddress = vm.addr(999);

        // Deploy proxy without initialization
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        Token proxyToken = Token(address(proxy));

        // Simulate legacy contract state where owner is already set (defensive check at line 174)
        // Owner slot is at position 0 in OwnableOnceNext2StepUpgradeable
        vm.store(address(proxy), bytes32(uint256(0)), bytes32(uint256(uint160(vm.addr(999)))));

        vm.expectRevert(AlreadyInitialized.selector);
        proxyToken.init(randomAddress, address(complianceProxy), "Test Token", "TEST", 18, address(0));
    }

    // ============ Internal Function Zero Address Tests ============

    function test_internalTransfer_RevertWhen_FromZeroAddress() public {
        TestTokenInternal implementation = new TestTokenInternal();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        bytes memory initData = abi.encodeWithSelector(
            Token.init.selector,
            address(identityRegistry),
            address(complianceProxy),
            "Test Token",
            "TEST",
            18,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        TestTokenInternal testToken = TestTokenInternal(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSpender.selector, address(0)));
        testToken.exposeTransfer(address(0), bob, 100);
    }

    function test_internalTransfer_RevertWhen_ToZeroAddress() public {
        TestTokenInternal implementation = new TestTokenInternal();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        bytes memory initData = abi.encodeWithSelector(
            Token.init.selector,
            address(identityRegistry),
            address(complianceProxy),
            "Test Token",
            "TEST",
            18,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        TestTokenInternal testToken = TestTokenInternal(address(proxy));

        testToken.addAgent(tokenAgent);
        vm.prank(tokenAgent);
        testToken.mint(alice, 1000);

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
        testToken.exposeTransfer(alice, address(0), 100);
    }

    function test_internalMint_RevertWhen_UserAddressZero() public {
        TestTokenInternal implementation = new TestTokenInternal();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        bytes memory initData = abi.encodeWithSelector(
            Token.init.selector,
            address(identityRegistry),
            address(complianceProxy),
            "Test Token",
            "TEST",
            18,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        TestTokenInternal testToken = TestTokenInternal(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
        testToken.exposeMint(address(0), 100);
    }

    function test_internalBurn_RevertWhen_UserAddressZero() public {
        TestTokenInternal implementation = new TestTokenInternal();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        bytes memory initData = abi.encodeWithSelector(
            Token.init.selector,
            address(identityRegistry),
            address(complianceProxy),
            "Test Token",
            "TEST",
            18,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        TestTokenInternal testToken = TestTokenInternal(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSpender.selector, address(0)));
        testToken.exposeBurn(address(0), 100);
    }

    function test_internalApprove_RevertWhen_OwnerZeroAddress() public {
        TestTokenInternal implementation = new TestTokenInternal();
        ModularComplianceProxy complianceProxy = new ModularComplianceProxy(address(getTREXImplementationAuthority()));
        Ownable(address(complianceProxy)).transferOwnership(deployer);

        bytes memory initData = abi.encodeWithSelector(
            Token.init.selector,
            address(identityRegistry),
            address(complianceProxy),
            "Test Token",
            "TEST",
            18,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        TestTokenInternal testToken = TestTokenInternal(address(proxy));

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSender.selector, address(0)));
        testToken.exposeApprove(address(0), bob, 100);
    }

}
