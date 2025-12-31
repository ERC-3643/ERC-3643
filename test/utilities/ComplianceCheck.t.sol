// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockContract } from "contracts/_testContracts/MockContract.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { UtilityChecker } from "contracts/utils/UtilityChecker.sol";
import { Test } from "forge-std/Test.sol";

contract ComplianceCheckTest is Test {

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    ModularCompliance public compliance;
    TestModule public testModule;
    MockContract public mockContract;
    UtilityChecker public utilityChecker;

    function setUp() public {
        // Deploy ModularCompliance implementation
        ModularCompliance complianceImplementation = new ModularCompliance();

        // Deploy ModularCompliance proxy with init using ERC1967Proxy
        bytes memory initData = abi.encodeWithSelector(ModularCompliance.init.selector);
        ERC1967Proxy complianceProxy = new ERC1967Proxy(address(complianceImplementation), initData);
        compliance = ModularCompliance(address(complianceProxy));

        // Transfer ownership to deployer
        // Proxy is owned by the deployer (test contract)
        compliance.transferOwnership(deployer);

        // Deploy TestModule implementation
        TestModule testModuleImplementation = new TestModule();

        // Deploy TestModule proxy with initialize using ModuleProxy
        bytes memory moduleInitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModuleProxy = new ModuleProxy(address(testModuleImplementation), moduleInitData);
        testModule = TestModule(address(testModuleProxy));

        // Add module to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule));

        // Deploy MockContract
        mockContract = new MockContract();

        // Bind token to compliance
        vm.prank(deployer);
        compliance.bindToken(address(mockContract));

        // Set compliance on mock contract
        mockContract.setCompliance(address(compliance));

        // Deploy UtilityChecker
        utilityChecker = new UtilityChecker();
        utilityChecker.initialize();
    }

    // ============ getTransferDetails() Tests ============

    /// @notice Should return pass for single module
    function test_getTransferDetails_ReturnsPass_ForSingleModule() public {
        UtilityChecker.ComplianceCheckDetails[] memory results =
            utilityChecker.getTransferDetails(address(mockContract), alice, bob, 100);

        assertEq(results.length, 1);
        assertEq(keccak256(bytes(results[0].moduleName)), keccak256(bytes("TestModule")));
        assertTrue(results[0].pass);
    }

    /// @notice Should return no pass for one of multiple modules
    function test_getTransferDetails_ReturnsNoPass_ForOneOfMultipleModules() public {
        // Deploy second module with proxy
        TestModule testModule2Implementation = new TestModule();
        bytes memory module2InitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModule2Proxy = new ModuleProxy(address(testModule2Implementation), module2InitData);
        TestModule testModule2 = TestModule(address(testModule2Proxy));

        // Add the proxy address to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule2));

        // Block the second test module to show 2 different outputs
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule2));

        UtilityChecker.ComplianceCheckDetails[] memory results =
            utilityChecker.getTransferDetails(address(mockContract), alice, bob, 100);

        assertEq(results.length, 2);
        assertEq(keccak256(bytes(results[0].moduleName)), keccak256(bytes("TestModule")));
        assertTrue(results[0].pass);
        assertEq(keccak256(bytes(results[1].moduleName)), keccak256(bytes("TestModule")));
        assertFalse(results[1].pass);
    }

    /// @notice Should return pass for multiple modules
    function test_getTransferDetails_ReturnsPass_ForMultipleModules() public {
        // Deploy second module with proxy
        TestModule testModule2Implementation = new TestModule();
        bytes memory module2InitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModule2Proxy = new ModuleProxy(address(testModule2Implementation), module2InitData);
        TestModule testModule2 = TestModule(address(testModule2Proxy));

        // Add the proxy address to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule2));

        UtilityChecker.ComplianceCheckDetails[] memory results =
            utilityChecker.getTransferDetails(address(mockContract), alice, bob, 100);

        assertEq(results.length, 2);
        assertEq(keccak256(bytes(results[0].moduleName)), keccak256(bytes("TestModule")));
        assertTrue(results[0].pass);
        assertEq(keccak256(bytes(results[1].moduleName)), keccak256(bytes("TestModule")));
        assertTrue(results[1].pass);
    }

}
