// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { InvalidImplementationAuthority } from "contracts/errors/CommonErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { OnlyCurrentImplementationAuthorityCanCall } from "contracts/proxy/AbstractProxy.sol";
import { ModularComplianceProxy } from "contracts/proxy/ModularComplianceProxy.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { ImplementationAuthoritySet } from "contracts/proxy/interface/IProxy.sol";
import { IProxy } from "contracts/proxy/interface/IProxy.sol";
import { Test } from "forge-std/Test.sol";
import { ImplementationAuthorityHelper } from "test/helpers/ImplementationAuthorityHelper.sol";

contract AbstractProxyTest is Test {

    address public deployer = makeAddr("deployer");
    IProxy public proxy;
    TREXImplementationAuthority public implementationAuthority;

    function setUp() public {
        // Deploy a complete Implementation Authority (reference = true is needed for proxy construction)
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory setup =
            ImplementationAuthorityHelper.deploy(true);
        implementationAuthority = setup.implementationAuthority;

        // Deploy ModularComplianceProxy (which inherits from AbstractProxy)
        proxy = IProxy(address(new ModularComplianceProxy(address(implementationAuthority))));
    }

    // ============ setImplementationAuthority() Tests ============

    /// @notice Should revert when called by non-implementation authority
    function test_setImplementationAuthority_RevertWhen_NotImplementationAuthority() public {
        address randomAddress = makeAddr("random");
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory newIASetup =
            ImplementationAuthorityHelper.deploy(true);

        vm.prank(randomAddress);
        vm.expectRevert(OnlyCurrentImplementationAuthorityCanCall.selector);
        proxy.setImplementationAuthority(address(newIASetup.implementationAuthority));
    }

    /// @notice Should revert when new implementation authority is zero address
    function test_setImplementationAuthority_RevertWhen_ZeroAddress() public {
        vm.prank(address(implementationAuthority));
        vm.expectRevert(ZeroAddress.selector);
        proxy.setImplementationAuthority(address(0));
    }

    /// @notice Should revert when new implementation authority is incomplete
    function test_setImplementationAuthority_RevertWhen_IncompleteIA() public {
        // Deploy an incomplete IA (no implementations set)
        TREXImplementationAuthority incompleteIA = new TREXImplementationAuthority(false, address(0), address(0));

        vm.prank(address(implementationAuthority));
        vm.expectRevert(InvalidImplementationAuthority.selector);
        proxy.setImplementationAuthority(address(incompleteIA));
    }

    /// @notice Should succeed when called by implementation authority with complete IA
    function test_setImplementationAuthority_Success() public {
        ImplementationAuthorityHelper.ImplementationAuthoritySetup memory newIASetup =
            ImplementationAuthorityHelper.deploy(true);

        vm.prank(address(implementationAuthority));
        vm.expectEmit(true, false, false, false);
        emit ImplementationAuthoritySet(address(newIASetup.implementationAuthority));
        proxy.setImplementationAuthority(address(newIASetup.implementationAuthority));

        assertEq(
            proxy.getImplementationAuthority(), address(newIASetup.implementationAuthority), "IA should be updated"
        );
    }

}
