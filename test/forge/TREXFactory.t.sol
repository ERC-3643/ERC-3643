// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { TREXFactory } from "contracts/factory/TREXFactory.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { TREXFactorySetup } from "test/forge/helpers/TREXFactorySetup.sol";

/// @title TREXFactoryTest
contract TREXFactoryTest is TREXFactorySetup {

    function test_TREXSuiteDeploys() public view {
        // Verify all components are deployed
        assertNotEq(address(trexFactory), address(0), "TREX Factory should be deployed");
        assertNotEq(address(getTREXImplementationAuthority()), address(0), "TREX IA should be deployed");
        assertNotEq(address(getIdFactory()), address(0), "IdFactory should be deployed");
    }

    function test_StandardAddressesSet() public view {
        // Verify standard addresses are set
        assertNotEq(deployer, address(0), "Deployer should be set");
        assertNotEq(alice, address(0), "Alice should be set");
        assertNotEq(bob, address(0), "Bob should be set");
    }

    function test_TREXFactoryLinked() public view {
        TREXFactory factory = trexFactory;
        TREXImplementationAuthority ia = getTREXImplementationAuthority();

        // Verify factory knows about IA
        assertEq(factory.getImplementationAuthority(), address(ia), "Factory should reference IA");
        assertEq(factory.getIdFactory(), address(getIdFactory()), "Factory should reference IdFactory");
    }

}
