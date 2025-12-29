// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC3643 } from "contracts/ERC-3643/IERC3643.sol";
import { ComplianceAdded } from "contracts/ERC-3643/IERC3643.sol";
import { IERC3643Compliance } from "contracts/ERC-3643/IERC3643Compliance.sol";
import { TokenBound, TokenUnbound } from "contracts/ERC-3643/IERC3643Compliance.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { MockContract } from "contracts/_testContracts/MockContract.sol";
import { ModuleNotPnP } from "contracts/_testContracts/ModuleNotPnP.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { IModularCompliance } from "contracts/compliance/modular/IModularCompliance.sol";
import { ModuleAdded, ModuleInteraction, ModuleRemoved } from "contracts/compliance/modular/IModularCompliance.sol";
import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import {
    MaxModulesReached,
    ModuleAlreadyBound,
    ModuleNotBound,
    OnlyOwnerOrTokenCanCall,
    TokenNotBound
} from "contracts/compliance/modular/ModularCompliance.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { ArraySizeLimited, OwnableUnauthorizedAccount } from "contracts/errors/CommonErrors.sol";
import { InitializationFailed } from "contracts/errors/CommonErrors.sol";
import {
    AddressNotATokenBoundToComplianceContract,
    ComplianceNotSuitableForBindingToModule
} from "contracts/errors/ComplianceErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { ZeroValue } from "contracts/errors/InvalidArgumentErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { ModularComplianceProxy } from "contracts/proxy/ModularComplianceProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { OwnableOnceNext2StepUpgradeable } from "contracts/roles/OwnableOnceNext2StepUpgradeable.sol";
import { OwnershipTransferStarted } from "contracts/roles/OwnableOnceNext2StepUpgradeable.sol";
import { Token } from "contracts/token/Token.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { IdentityFactoryHelper } from "test/helpers/IdentityFactoryHelper.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract ComplianceTest is TREXFactorySetup {

    ModularCompliance public compliance;
    ModularCompliance public complianceBeta;
    Token public token;
    address public tokenAgent = makeAddr("tokenAgent");

    /// @notice Helper to deploy TestModule with proxy
    function _deployTestModuleWithProxy() internal returns (address moduleAddress) {
        TestModule moduleImplementation = new TestModule();
        bytes memory initData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy moduleProxy = new ModuleProxy(address(moduleImplementation), initData);
        moduleAddress = address(moduleProxy);
    }

    /// @notice Helper to deploy ModuleNotPnP with proxy
    function _deployModuleNotPnPWithProxy() internal returns (address moduleAddress) {
        ModuleNotPnP moduleImplementation = new ModuleNotPnP();
        bytes memory initData = abi.encodeWithSelector(ModuleNotPnP.initialize.selector);
        ModuleProxy moduleProxy = new ModuleProxy(address(moduleImplementation), initData);
        moduleAddress = address(moduleProxy);
    }

    /// @notice Helper to deploy ModularCompliance with proxy
    function _deployModularComplianceWithProxy(address implementationAuthority) internal returns (ModularCompliance) {
        ModularComplianceProxy proxy = new ModularComplianceProxy(implementationAuthority);
        return ModularCompliance(address(proxy));
    }

    function setUp() public override {
        super.setUp();

        // Deploy token suite
        token = _deployToken("salt");

        // Deploy two compliance contracts
        compliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        complianceBeta = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));

        // Transfer ownership of compliance contracts to deployer (they're owned by test contract initially)
        vm.startPrank(address(this));
        compliance.transferOwnership(deployer);
        complianceBeta.transferOwnership(deployer);
        vm.stopPrank();

        // Bind compliance to token
        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Add tokenAgent as an agent to Token and IdentityRegistry (for burn operations)
        IERC3643IdentityRegistry ir = token.identityRegistry();
        vm.startPrank(deployer);
        token.addAgent(tokenAgent);
        IdentityRegistry(address(ir)).addAgent(tokenAgent);
        vm.stopPrank();

        // Register alice and bob identities and mint tokens (for tests that need them)
        vm.startPrank(tokenAgent);
        IdentityRegistry(address(ir)).registerIdentity(alice, aliceIdentity, 42);
        IdentityRegistry(address(ir)).registerIdentity(bob, bobIdentity, 666);
        token.mint(alice, 1000);
        token.mint(bob, 500);
        vm.stopPrank();
    }

    // ============================================
    // .init Tests
    // ============================================

    /// @notice Should prevent calling init twice
    function test_init_RevertWhen_CalledTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        compliance.init();
    }

    // ============================================
    // Constructor Tests
    // ============================================

    /// @notice Should revert when implementation authority is zero address
    function test_constructor_RevertWhen_ImplementationAuthorityZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new ModularComplianceProxy(address(0));
    }

    /// @notice Should revert when initialization fails (invalid implementation)
    function test_constructor_RevertWhen_InitializationFails() public {
        // Deploy a mock contract that doesn't have init() function
        MockContract mockImpl = new MockContract();

        // Deploy an IA and manually set an invalid MC implementation
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(true, address(0), address(0));

        // Create a version with invalid MC implementation (mock contract without init())
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(mockImpl), // Invalid - doesn't have proper init
            ctrImplementation: address(mockImpl), // Invalid
            irImplementation: address(mockImpl), // Invalid
            irsImplementation: address(mockImpl), // Invalid
            tirImplementation: address(mockImpl), // Invalid
            mcImplementation: address(mockImpl) // Invalid - doesn't have init() function
        });

        // Add version to IA (need to be owner)
        Ownable(address(incompleteIA)).transferOwnership(deployer);
        vm.prank(deployer);
        incompleteIA.addAndUseTREXVersion(version, contracts);

        // Now try to deploy proxy - delegatecall to mockImpl.init() will fail
        // because MockContract doesn't have init() function, causing InitializationFailed() revert
        vm.expectRevert(InitializationFailed.selector);
        new ModularComplianceProxy(address(incompleteIA));
    }

    // ============================================
    // .bindToken Tests
    // ============================================

    /// @notice Should revert when calling as another account than the owner
    function test_bindToken_RevertWhen_CalledByNonOwner() public {
        vm.prank(another);
        vm.expectRevert(OnlyOwnerOrTokenCanCall.selector);
        compliance.bindToken(address(token));
    }

    /// @notice Should revert when compliance is already bound and caller is not token
    function test_bindToken_RevertWhen_AlreadyBoundAndNotToken() public {
        // Deploy new compliance and bind it to token
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(deployer);

        vm.prank(deployer);
        newCompliance.bindToken(address(token));

        // Try to bind again as another account
        vm.prank(another);
        vm.expectRevert(OnlyOwnerOrTokenCanCall.selector);
        newCompliance.bindToken(address(token));
    }

    /// @notice Should set the new compliance when calling as the token
    function test_bindToken_Success_WhenCalledByToken() public {
        // Deploy a fresh token suite (without compliance bound)
        Token testToken = _deployToken("salt2");

        // Deploy a compliance and bind it
        ModularCompliance compliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        compliance.transferOwnership(deployer);
        vm.prank(deployer);
        compliance.bindToken(address(testToken));

        // Deploy new compliance (not bound yet)
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(deployer);

        // Verify new compliance is not bound yet
        assertFalse(newCompliance.isTokenBound(address(testToken)));

        {
            // Token sets new compliance (this should bind it)
            // Event order: TokenBound (new), then the second event ComplianceAdded (token)
            vm.expectEmit(true, false, false, false, address(newCompliance));
            emit TokenBound(address(testToken));

            vm.expectEmit(true, false, false, false, address(testToken));
            emit ComplianceAdded(address(newCompliance));

            vm.prank(deployer);
            testToken.setCompliance(address(newCompliance));
        }

        assertTrue(newCompliance.isTokenBound(address(testToken)));
    }

    /// @notice Should revert when token address is zero
    function test_bindToken_RevertWhen_TokenAddressIsZero() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        newCompliance.bindToken(address(0));
    }

    // ============================================
    // .unbindToken Tests
    // ============================================

    /// @notice Should revert when calling as another account
    function test_unbindToken_RevertWhen_CalledByNonOwner() public {
        vm.prank(another);
        vm.expectRevert(OnlyOwnerOrTokenCanCall.selector);
        compliance.unbindToken(address(token));
    }

    /// @notice Should revert when token is zero address
    function test_unbindToken_RevertWhen_TokenIsZeroAddress() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        newCompliance.unbindToken(address(0));
    }

    /// @notice Should revert when token is not bound
    function test_unbindToken_RevertWhen_TokenNotBound() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(deployer);

        vm.prank(deployer);
        vm.expectRevert(TokenNotBound.selector);
        newCompliance.unbindToken(address(token));
    }

    /// @notice Should bind the new compliance to the token when called as token
    function test_unbindToken_Success_WhenCalledByToken() public {
        // Ensure compliance is bound to token first (matching Hardhat test)
        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Set new compliance (this triggers unbind on old compliance)
        // Event order: TokenUnbound (old) -> TokenBound (new) -> ComplianceAdded (token)
        vm.expectEmit(true, false, false, false, address(compliance));
        emit TokenUnbound(address(token));

        vm.expectEmit(true, false, false, false, address(complianceBeta));
        emit TokenBound(address(token));

        vm.expectEmit(true, false, false, false, address(token));
        emit ComplianceAdded(address(complianceBeta));

        vm.prank(deployer);
        token.setCompliance(address(complianceBeta));

        assertEq(complianceBeta.getTokenBound(), address(token));
        assertFalse(compliance.isTokenBound(address(token)));
    }

    // ============================================
    // .addModule Tests
    // ============================================

    /// @notice Should revert when not calling as the owner
    function test_addModule_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        compliance.addModule(address(0));
    }

    /// @notice Should revert when module address is zero
    function test_addModule_RevertWhen_ModuleAddressIsZero() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        compliance.addModule(address(0));
    }

    /// @notice Should revert when module address is already bound
    function test_addModule_RevertWhen_ModuleAlreadyBound() public {
        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        vm.prank(deployer);
        vm.expectRevert(ModuleAlreadyBound.selector);
        compliance.addModule(moduleAddress);
    }

    /// @notice Should revert when module is not plug & play and compliance is not suitable
    function test_addModule_RevertWhen_ModuleNotPnPAndNotSuitable() public {
        vm.prank(deployer);
        compliance.bindToken(address(token));

        address moduleAddress = _deployModuleNotPnPWithProxy();
        ModuleNotPnP module = ModuleNotPnP(moduleAddress);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(ComplianceNotSuitableForBindingToModule.selector, moduleAddress));
        compliance.addModule(moduleAddress);
    }

    /// @notice Should bind when module is not plug & play but compliance is suitable
    function test_addModule_Success_WhenModuleNotPnPAndSuitable() public {
        vm.prank(deployer);
        compliance.bindToken(address(token));

        // Burn tokens to make compliance suitable
        vm.prank(tokenAgent);
        token.burn(alice, 1000);
        vm.prank(tokenAgent);
        token.burn(bob, 500);

        address moduleAddress = _deployModuleNotPnPWithProxy();
        ModuleNotPnP module = ModuleNotPnP(moduleAddress);

        // Set module as ready for this compliance
        vm.prank(deployer);
        module.setModuleReady(address(compliance), true);

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleAdded(moduleAddress);
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        address[] memory modules = compliance.getModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], moduleAddress);
    }

    /// @notice Should add the module when module is plug & play
    function test_addModule_Success_WhenModuleIsPlugAndPlay() public {
        address moduleAddress = _deployTestModuleWithProxy();

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleAdded(moduleAddress);
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        address[] memory modules = compliance.getModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], moduleAddress);
    }

    /// @notice Should revert when attempting to bind a 25th module
    function test_addModule_RevertWhen_MaxModulesReached() public {
        // Add 24 modules (max is 25, so 24 + 1 more = 25)
        for (uint256 i = 0; i < 24; i++) {
            address moduleAddress = _deployTestModuleWithProxy();
            vm.prank(deployer);
            compliance.addModule(moduleAddress);
        }

        // Add 25th module
        address module25 = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(module25);

        // Try to add 26th module (should revert)
        address module26 = _deployTestModuleWithProxy();
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(MaxModulesReached.selector, 25));
        compliance.addModule(module26);
    }

    // ============================================
    // .removeModule Tests
    // ============================================

    /// @notice Should revert when not calling as owner
    function test_removeModule_RevertWhen_NotOwner() public {
        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        compliance.removeModule(address(0));
    }

    /// @notice Should revert when module address is zero
    function test_removeModule_RevertWhen_ModuleAddressIsZero() public {
        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        compliance.removeModule(address(0));
    }

    /// @notice Should revert when module address is not bound
    function test_removeModule_RevertWhen_ModuleNotBound() public {
        address moduleAddress = _deployTestModuleWithProxy();

        vm.prank(deployer);
        vm.expectRevert(ModuleNotBound.selector);
        compliance.removeModule(moduleAddress);
    }

    /// @notice Should remove the module when module is bound
    function test_removeModule_Success_WhenModuleBound() public {
        address moduleA = _deployTestModuleWithProxy();
        address moduleB = _deployTestModuleWithProxy();

        vm.prank(deployer);
        compliance.addModule(moduleA);
        vm.prank(deployer);
        compliance.addModule(moduleB);

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleRemoved(moduleB);
        vm.prank(deployer);
        compliance.removeModule(moduleB);

        assertFalse(compliance.isModuleBound(moduleB));
    }

    // ============================================
    // .transferred Tests
    // ============================================

    /// @notice Should revert when not calling as a bound token
    function test_transferred_RevertWhen_NotBoundToken() public {
        vm.prank(another);
        vm.expectRevert(AddressNotATokenBoundToComplianceContract.selector);
        compliance.transferred(address(0), address(0), 0);
    }

    /// @notice Should revert when from address is null
    function test_transferred_RevertWhen_FromAddressIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroAddress.selector);
        compliance.transferred(address(0), bob, 10);
    }

    /// @notice Should revert when to address is null
    function test_transferred_RevertWhen_ToAddressIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroAddress.selector);
        compliance.transferred(alice, address(0), 10);
    }

    /// @notice Should revert when amount is zero
    function test_transferred_RevertWhen_AmountIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroValue.selector);
        compliance.transferred(alice, bob, 0);
    }

    /// @notice Should update the modules when amount is greater than zero
    function test_transferred_Success_WhenAmountGreaterThanZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        compliance.transferred(alice, bob, 10);
    }

    // ============================================
    // .created Tests
    // ============================================

    /// @notice Should revert when not calling as a bound token
    function test_created_RevertWhen_NotBoundToken() public {
        vm.prank(another);
        vm.expectRevert(AddressNotATokenBoundToComplianceContract.selector);
        compliance.created(address(0), 0);
    }

    /// @notice Should revert when to address is null
    function test_created_RevertWhen_ToAddressIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroAddress.selector);
        compliance.created(address(0), 10);
    }

    /// @notice Should revert when amount is zero
    function test_created_RevertWhen_AmountIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroValue.selector);
        compliance.created(bob, 0);
    }

    /// @notice Should update the modules when amount is greater than zero
    function test_created_Success_WhenAmountGreaterThanZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        compliance.created(bob, 10);
    }

    /// @notice Should call moduleMintAction on all bound modules
    function test_created_Success_CallsModuleMintAction() public {
        Token testToken = _setupComplianceBoundToWallet();

        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        vm.prank(address(testToken));
        compliance.created(bob, 100);
    }

    // ============================================
    // .destroyed Tests
    // ============================================

    /// @notice Should revert when not calling as a bound token
    function test_destroyed_RevertWhen_NotBoundToken() public {
        vm.prank(another);
        vm.expectRevert(AddressNotATokenBoundToComplianceContract.selector);
        compliance.destroyed(address(0), 0);
    }

    /// @notice Should revert when from address is null
    function test_destroyed_RevertWhen_FromAddressIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroAddress.selector);
        compliance.destroyed(address(0), 10);
    }

    /// @notice Should revert when amount is zero
    function test_destroyed_RevertWhen_AmountIsZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        vm.expectRevert(ZeroValue.selector);
        compliance.destroyed(alice, 0);
    }

    /// @notice Should update the modules when amount is greater than zero
    function test_destroyed_Success_WhenAmountGreaterThanZero() public {
        Token testToken = _setupComplianceBoundToWallet();

        vm.prank(address(testToken));
        compliance.destroyed(alice, 10);
    }

    /// @notice Should call moduleBurnAction on all bound modules
    function test_destroyed_Success_CallsModuleBurnAction() public {
        Token testToken = _setupComplianceBoundToWallet();

        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        vm.prank(address(testToken));
        compliance.destroyed(alice, 100);
    }

    // ============================================
    // .callModuleFunction Tests
    // ============================================

    /// @notice Should revert when sender is not the owner
    function test_callModuleFunction_RevertWhen_NotOwner() public {
        vm.prank(another);
        bytes memory randomData = new bytes(32);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        compliance.callModuleFunction(randomData, address(0));
    }

    /// @notice Should revert when module is not bound
    function test_callModuleFunction_RevertWhen_ModuleNotBound() public {
        vm.prank(deployer);
        bytes memory randomData = new bytes(32);
        vm.expectRevert(ModuleNotBound.selector);
        compliance.callModuleFunction(randomData, address(0));
    }

    /// @notice Should call module function and emit ModuleInteraction event
    function test_callModuleFunction_Success_EmitsModuleInteraction() public {
        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        bytes memory callData = abi.encodeWithSignature("blockModule(bool)", true);
        bytes4 expectedSelector = bytes4(callData);

        vm.expectEmit(true, true, false, false, address(compliance));
        emit ModuleInteraction(moduleAddress, expectedSelector);

        vm.prank(deployer);
        compliance.callModuleFunction(callData, moduleAddress);
    }

    /// @notice Should revert when module function call fails
    function test_callModuleFunction_RevertWhen_ModuleCallFails() public {
        // Use ModuleNotPnP which doesn't have a fallback function
        // So calls to non-existent functions will revert
        address moduleAddress = _deployModuleNotPnPWithProxy();

        vm.prank(deployer);
        compliance.bindToken(address(token));

        // Make compliance suitable for ModuleNotPnP by burning tokens
        vm.startPrank(tokenAgent);
        token.burn(alice, 1000);
        token.burn(bob, 500);
        vm.stopPrank();

        // Set module as ready for this compliance and add it
        vm.startPrank(deployer);
        ModuleNotPnP(moduleAddress).setModuleReady(address(compliance), true);
        compliance.addModule(moduleAddress);
        vm.stopPrank();

        // Call a non-existent function to trigger revert (no fallback function)
        bytes memory callData = abi.encodeWithSignature("nonExistentFunction()");

        vm.prank(deployer);
        vm.expectRevert();
        compliance.callModuleFunction(callData, moduleAddress);
    }

    /// @notice Should handle callData with length less than 4 bytes
    function test_callModuleFunction_Success_WithShortCallData() public {
        // Use TestModule which has a fallback function
        // This allows the module call to succeed even with invalid callData
        address moduleAddress = _deployTestModuleWithProxy();

        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        // Create callData with less than 4 bytes (covers _selector's return bytes4(0) path)
        bytes memory shortCallData = new bytes(3);
        shortCallData[0] = 0x12;
        shortCallData[1] = 0x34;
        shortCallData[2] = 0x56;

        // The fallback function accepts any callData, so the module call succeeds
        // This allows _selector to be called with short callData, testing the explicit return
        vm.expectEmit(true, true, false, false, address(compliance));
        emit ModuleInteraction(moduleAddress, bytes4(0));
        vm.prank(deployer);
        compliance.callModuleFunction(shortCallData, moduleAddress);
    }

    // ============================================
    // .addAndSetModule Tests
    // ============================================

    /// @notice Should revert when not calling as the owner
    function test_addAndSetModule_RevertWhen_NotOwner() public {
        address moduleAddress = _deployTestModuleWithProxy();
        bytes[] memory interactions = new bytes[](0);

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        compliance.addAndSetModule(moduleAddress, interactions);
    }

    /// @notice Should revert when interactions array exceeds 5 elements
    function test_addAndSetModule_RevertWhen_InteractionsArrayExceeds5() public {
        address moduleAddress = _deployTestModuleWithProxy();
        bytes[] memory interactions = new bytes[](6);
        for (uint256 i = 0; i < 6; i++) {
            interactions[i] = abi.encodeWithSignature("someFunction()");
        }

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(ArraySizeLimited.selector, 5));
        compliance.addAndSetModule(moduleAddress, interactions);
    }

    /// @notice Should add module and perform interactions
    function test_addAndSetModule_Success_WithInteractions() public {
        address moduleAddress = _deployTestModuleWithProxy();
        bytes[] memory interactions = new bytes[](2);
        interactions[0] = abi.encodeWithSignature("blockModule(bool)", true);
        interactions[1] = abi.encodeWithSignature("blockModule(bool)", false);

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleAdded(moduleAddress);

        vm.expectEmit(true, true, false, false, address(compliance));
        emit ModuleInteraction(moduleAddress, bytes4(interactions[0]));

        vm.prank(deployer);
        compliance.addAndSetModule(moduleAddress, interactions);

        assertTrue(compliance.isModuleBound(moduleAddress));
    }

    /// @notice Should work with empty interactions array
    function test_addAndSetModule_Success_WithEmptyInteractions() public {
        address moduleAddress = _deployTestModuleWithProxy();
        bytes[] memory interactions = new bytes[](0);

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleAdded(moduleAddress);

        vm.prank(deployer);
        compliance.addAndSetModule(moduleAddress, interactions);

        assertTrue(compliance.isModuleBound(moduleAddress));
    }

    // ============================================
    // .supportsInterface Tests
    // ============================================

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupportedInterface() public {
        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(compliance.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the IModularCompliance interface ID
    function test_supportsInterface_ReturnsTrue_ForIModularCompliance() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIModularComplianceInterfaceId();
        assertTrue(compliance.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC3643Compliance interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC3643Compliance() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC3643ComplianceInterfaceId();
        assertTrue(compliance.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(compliance.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(compliance.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IModule interface ID
    function test_getIModuleInterfaceId_ReturnsCorrectId() public {
        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIModuleInterfaceId();

        // Deploy a test module to verify the interface ID
        address moduleAddress = _deployTestModuleWithProxy();
        TestModule testModule = TestModule(moduleAddress);
        assertTrue(testModule.supportsInterface(interfaceId));
    }

    // ============================================
    // Edge Cases Tests
    // ============================================

    /// @notice Should return false if any module check fails
    function test_canTransfer_ReturnsFalse_WhenBlockedModule() public {
        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        // Block the module to make moduleCheck return false
        bytes memory callData = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(callData, moduleAddress);

        bool result = compliance.canTransfer(alice, bob, 100);
        assertFalse(result);
    }

    /// @notice Should return true when all modules pass
    function test_canTransfer_ReturnsTrue_WhenAllModulesPass() public {
        address moduleAddress = _deployTestModuleWithProxy();
        vm.prank(deployer);
        compliance.addModule(moduleAddress);

        // Ensure module is not blocked (default state allows transfers)
        bool result = compliance.canTransfer(alice, bob, 100);
        assertTrue(result);
    }

    /// @notice Should still remove the module from array when removing middle module
    function test_removeModule_Success_RemovesMiddleModule() public {
        address moduleA = _deployTestModuleWithProxy();
        address moduleB = _deployTestModuleWithProxy();
        address moduleC = _deployTestModuleWithProxy();

        vm.prank(deployer);
        compliance.addModule(moduleA);
        vm.prank(deployer);
        compliance.addModule(moduleB);
        vm.prank(deployer);
        compliance.addModule(moduleC);

        vm.expectEmit(true, false, false, false, address(compliance));
        emit ModuleRemoved(moduleB);

        vm.prank(deployer);
        compliance.removeModule(moduleB);

        address[] memory modules = compliance.getModules();
        assertEq(modules.length, 2);
        // Check that moduleA and moduleC are present, moduleB is not
        bool foundA = false;
        bool foundC = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i] == moduleA) foundA = true;
            if (modules[i] == moduleC) foundC = true;
            assertTrue(modules[i] != moduleB);
        }
        assertTrue(foundA);
        assertTrue(foundC);
    }

    // ============================================
    // OwnableOnceNext2StepUpgradeable Tests
    // ============================================

    /// @notice Should set owner to caller when first deploy
    function test_OwnableOnceNext2StepUpgradeable_SetsOwner_WhenFirstDeploy() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        // Owner is initially the deployer (test contract)
        assertEq(newCompliance.owner(), address(this));
    }

    /// @notice Should set next owner to caller when set first owner
    function test_OwnableOnceNext2StepUpgradeable_SetsNextOwner_WhenSetFirstOwner() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(alice);

        assertEq(newCompliance.owner(), alice);
    }

    /// @notice Should set owner to next owner in 2 steps
    function test_OwnableOnceNext2StepUpgradeable_SetsOwnerIn2Steps() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(alice);

        vm.expectEmit(true, true, false, false, address(newCompliance));
        emit OwnershipTransferStarted(alice, bob);

        vm.prank(alice);
        newCompliance.transferOwnership(bob);

        vm.expectEmit(true, true, false, false, address(newCompliance));
        emit Ownable.OwnershipTransferred(alice, bob);

        vm.prank(bob);
        newCompliance.acceptOwnership();

        assertEq(newCompliance.owner(), bob);
    }

    /// @notice Should revert when acceptOwnership is called by non-pending owner
    function test_OwnableOnceNext2StepUpgradeable_acceptOwnership_RevertWhen_NotPendingOwner() public {
        ModularCompliance newCompliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        newCompliance.transferOwnership(alice);

        vm.expectEmit(true, true, false, false, address(newCompliance));
        emit OwnershipTransferStarted(alice, bob);

        vm.prank(alice);
        newCompliance.transferOwnership(bob);

        // Try to accept ownership from a different address (not the pending owner)
        address charlie = makeAddr("charlie");
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, charlie));
        newCompliance.acceptOwnership();
    }

    // ============================================
    // Helper Functions
    // ============================================

    /// @notice Helper to deploy a token suite
    /// @param salt The salt for CREATE2 deployment
    /// @return testToken The deployed token
    function _deployToken(string memory salt) internal returns (Token testToken) {
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
        trexFactory.deployTREXSuite(salt, tokenDetails, claimDetails);
        testToken = Token(trexFactory.getToken(salt));
    }

    /// @notice Helper to setup compliance bound to token
    /// @return testToken The deployed token bound to the compliance
    function _setupComplianceBoundToWallet() internal returns (Token testToken) {
        // Deploy new compliance for this test
        compliance = _deployModularComplianceWithProxy(address(getTREXImplementationAuthority()));
        compliance.transferOwnership(deployer);

        // Deploy and add modules
        address moduleA = _deployTestModuleWithProxy();
        address moduleB = _deployTestModuleWithProxy();
        vm.startPrank(deployer);
        compliance.addModule(moduleA);
        compliance.addModule(moduleB);
        vm.stopPrank();

        // Deploy a token and bind compliance to it
        testToken = _deployToken("compliance-salt");

        // Bind compliance to token
        vm.prank(deployer);
        testToken.setCompliance(address(compliance));
    }

}
