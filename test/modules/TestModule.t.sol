// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { IModule } from "contracts/compliance/modular/modules/IModule.sol";
import { OnlyBoundComplianceCanCall } from "contracts/errors/ComplianceErrors.sol";
import { ComplianceNotBound } from "contracts/errors/ComplianceErrors.sol";
import { IERC173 } from "contracts/roles/IERC173.sol";
import { Test } from "forge-std/Test.sol";

/// @notice tests for TestModule multicall functionality
contract TestModuleTest is Test {

    // Contracts
    ModularCompliance public compliance;
    TestModule public testModule;

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public another = makeAddr("another");

    bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice Sets up ModularCompliance and TestModule
    function setUp() public {
        // Deploy ModularCompliance implementation
        ModularCompliance complianceImplementation = new ModularCompliance();

        // Deploy ModularCompliance proxy with init using ERC1967Proxy
        bytes memory initData = abi.encodeWithSelector(ModularCompliance.init.selector);
        ERC1967Proxy complianceProxy = new ERC1967Proxy(address(complianceImplementation), initData);
        compliance = ModularCompliance(address(complianceProxy));

        // Transfer ownership to deployer (owner is initially the test contract (address(this)) since it deploys the proxy)
        compliance.transferOwnership(deployer);

        // Deploy TestModule implementation
        TestModule testModuleImplementation = new TestModule();

        // Deploy TestModule proxy with initialize using ERC1967Proxy
        bytes memory moduleInitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ERC1967Proxy testModuleProxy = new ERC1967Proxy(address(testModuleImplementation), moduleInitData);
        testModule = TestModule(address(testModuleProxy));

        // Add module to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule));
    }

    /// @notice Should execute multiple doSomething calls in a single transaction
    function test_MultipleDoSomethingCalls_Success() public {
        // Encode function calls
        bytes memory doSomething42Data = abi.encodeWithSignature("doSomething(uint256)", 42);
        bytes memory doSomething43Data = abi.encodeWithSignature("doSomething(uint256)", 43);

        // Create array of call data for multicall
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = doSomething42Data;
        multicallData[1] = doSomething43Data;

        // Encode multicall
        bytes memory multicallEncoded = abi.encodeWithSignature("multicall(bytes[])", multicallData);

        // Call multicall via compliance
        vm.prank(deployer);
        compliance.callModuleFunction(multicallEncoded, address(testModule));

        // Verify state changes, the last call should overwrite the first one
        assertEq(testModule.getComplianceData(address(compliance)), 43);
    }

    /// @notice Should execute multiple blockModule calls in a single transaction
    function test_MultipleBlockModuleCalls_Success() public {
        // Encode function calls
        bytes memory blockModuleTrueData = abi.encodeWithSignature("blockModule(bool)", true);
        bytes memory blockModuleFalseData = abi.encodeWithSignature("blockModule(bool)", false);

        // Create array of call data for multicall
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = blockModuleTrueData;
        multicallData[1] = blockModuleFalseData;

        // Encode multicall
        bytes memory multicallEncoded = abi.encodeWithSignature("multicall(bytes[])", multicallData);

        // Call multicall via compliance, the compliance will call the multicall in the testModule which already has multicall functionality
        vm.prank(deployer);
        compliance.callModuleFunction(multicallEncoded, address(testModule));

        // Verify state changes, the last call should overwrite the first one
        assertEq(testModule.getBlockedTransfers(address(compliance)), false);
    }

    /// @notice Should execute mixed doSomething and blockModule calls in a single transaction
    function test_MixedDoSomethingAndBlockModuleCalls_Success() public {
        // Encode function calls
        bytes memory doSomething100Data = abi.encodeWithSignature("doSomething(uint256)", 100);
        bytes memory blockModuleTrueData = abi.encodeWithSignature("blockModule(bool)", true);
        bytes memory doSomething200Data = abi.encodeWithSignature("doSomething(uint256)", 200);

        // Create array of call data for multicall
        bytes[] memory multicallData = new bytes[](3);
        multicallData[0] = doSomething100Data;
        multicallData[1] = blockModuleTrueData;
        multicallData[2] = doSomething200Data;

        // Encode multicall
        bytes memory multicallEncoded = abi.encodeWithSignature("multicall(bytes[])", multicallData);

        // Call multicall via compliance
        vm.prank(deployer);
        compliance.callModuleFunction(multicallEncoded, address(testModule));

        // Verify state changes, both should be set to the last values
        assertEq(testModule.getComplianceData(address(compliance)), 200);
        assertEq(testModule.getBlockedTransfers(address(compliance)), true);
    }

    /// @notice Should revert when calling multicall directly on module, it should not be from compliance!
    function test_MulticallDirectlyOnModule_RevertWhen_NotFromCompliance() public {
        // Encode function call
        bytes memory doSomething42Data = abi.encodeWithSignature("doSomething(uint256)", 42);

        // Create array of call data for multicall
        bytes[] memory multicallData = new bytes[](1);
        multicallData[0] = doSomething42Data;

        // Expect revert when calling multicall directly on module
        vm.prank(deployer);
        vm.expectRevert(OnlyBoundComplianceCanCall.selector);
        testModule.multicall(multicallData);
    }

    // ============================================
    // isComplianceBound Tests
    // ============================================

    /// @notice Should return true when compliance is bound
    function test_isComplianceBound_ReturnsTrue_WhenBound() public view {
        assertTrue(testModule.isComplianceBound(address(compliance)));
    }

    /// @notice Should return false when compliance is not bound
    function test_isComplianceBound_ReturnsFalse_WhenNotBound() public {
        address unboundCompliance = makeAddr("unboundCompliance");
        assertFalse(testModule.isComplianceBound(unboundCompliance));
    }

    // ============================================
    // getNonce Tests
    // ============================================

    /// @notice Should return zero nonce initially
    function test_getNonce_ReturnsZero_Initially() public view {
        assertEq(testModule.getNonce(address(compliance)), 0);
    }

    /// @notice Should increment nonce when unbinding compliance
    function test_getNonce_Increments_WhenUnbinding() public {
        assertEq(testModule.getNonce(address(compliance)), 0);

        vm.prank(address(compliance));
        testModule.unbindCompliance(address(compliance));

        assertEq(testModule.getNonce(address(compliance)), 1);

        vm.prank(address(compliance));
        testModule.bindCompliance(address(compliance));

        vm.prank(address(compliance));
        testModule.unbindCompliance(address(compliance));

        assertEq(testModule.getNonce(address(compliance)), 2);
    }

    // ============================================
    // supportsInterface Tests
    // ============================================

    /// @notice Should return false for unsupported interface
    function test_supportsInterface_ReturnsFalse_ForUnsupported() public view {
        bytes4 unsupportedInterfaceId = bytes4(0x12345678);
        assertFalse(testModule.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should return true for IModule interface
    function test_supportsInterface_ReturnsTrue_ForIModule() public view {
        assertTrue(testModule.supportsInterface(type(IModule).interfaceId));
    }

    /// @notice Should return true for IERC173 interface
    function test_supportsInterface_ReturnsTrue_ForIERC173() public view {
        assertTrue(testModule.supportsInterface(type(IERC173).interfaceId));
    }

    /// @notice Should return true for IERC165 interface
    function test_supportsInterface_ReturnsTrue_ForIERC165() public view {
        assertTrue(testModule.supportsInterface(type(IERC165).interfaceId));
    }

    // ============================================
    // _authorizeUpgrade Tests (via upgradeToAndCall)
    // ============================================

    /// @notice Should upgrade module when called by owner (covers _authorizeUpgrade)
    function test_upgradeToAndCall_Success_CoversAuthorizeUpgrade() public {
        testModule.transferOwnership(deployer);

        TestModule newImplementation = new TestModule();

        bytes32 slotValueBefore = vm.load(address(testModule), IMPLEMENTATION_SLOT);
        address oldImplementation = address(uint160(uint256(slotValueBefore)));

        vm.prank(deployer);
        UUPSUpgradeable(address(testModule)).upgradeToAndCall(address(newImplementation), "");

        bytes32 slotValueAfter = vm.load(address(testModule), IMPLEMENTATION_SLOT);
        address actualImplementation = address(uint160(uint256(slotValueAfter)));

        assertEq(actualImplementation, address(newImplementation));
        assertNotEq(actualImplementation, oldImplementation);
    }

    /// @notice Should revert upgrade when not called by owner
    function test_upgradeToAndCall_RevertWhen_NotOwner() public {
        testModule.transferOwnership(deployer);

        TestModule newImplementation = new TestModule();

        vm.prank(alice);
        vm.expectRevert();
        UUPSUpgradeable(address(testModule)).upgradeToAndCall(address(newImplementation), "");
    }

    // ============================================
    // onlyBoundCompliance Modifier Tests
    // ============================================

    /// @notice Should succeed when compliance is bound
    function test_onlyBoundCompliance_Success_WhenBound() public {
        testModule.invokeOnlyBoundCompliance(address(compliance));
    }

    /// @notice Should revert when compliance is not bound
    function test_onlyBoundCompliance_RevertWhen_NotBound() public {
        address unboundCompliance = makeAddr("unboundCompliance");
        vm.expectRevert(ComplianceNotBound.selector);
        testModule.invokeOnlyBoundCompliance(unboundCompliance);
    }

}
