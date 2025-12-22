// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IdentityFactoryHelper } from "./IdentityFactoryHelper.sol";
import { ImplementationAuthorityHelper } from "./ImplementationAuthorityHelper.sol";
import { TREXFactoryHelper } from "./TREXFactoryHelper.sol";
import { IdFactory } from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TREXFactory } from "contracts/factory/TREXFactory.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { Test } from "forge-std/Test.sol";

/// @notice Comprehensive fixture that orchestrates all helpers to deploy the full ERC-3643/T-REX suite
/// @dev Combines all 3 helpers: IdentityFactoryHelper, ImplementationAuthorityHelper, TREXFactoryHelper
/// Provides standard test addresses and convenience getters for easy access to all components
contract TREXFactorySetup is Test {

    // ONCHAINID Setup
    IdentityFactoryHelper.ONCHAINIDSetup public onchainidSetup;

    // TREX Implementation Authority Setup
    ImplementationAuthorityHelper.ImplementationAuthoritySetup public implementationAuthoritySetup;

    // TREX Factory
    TREXFactory public trexFactory;

    // Standard test addresses
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public david = makeAddr("david");
    address public another = makeAddr("another");

    //identities for common test addresses
    IIdentity public aliceIdentity;
    IIdentity public bobIdentity;
    IIdentity public charlieIdentity;

    /// @notice Sets up the complete TREX infrastructure with standard test addresses
    /// Creates a reference Implementation Authority (isReference = true)
    function setUp() public virtual {
        // Deploy complete suite (reference Implementation authority = true for main setup)
        deploy(deployer, true);
    }

    /// @notice Deploys the complete TREX setup using all 3 helpers
    /// @param deployerAddress The deployer address (used as management key for Identity and as owner)
    /// @param isReference Whether to create a reference Implementation Authority
    /// @dev Ownership: Contracts are initially owned by TREXSuite (since deployed from contract).
    /// Ownership is transferred to deployerAddress where deployer is owner.
    function deploy(address deployerAddress, bool isReference) public {
        // Step 1: Deploy ONCHAINID Components
        onchainidSetup = IdentityFactoryHelper.deploy(deployerAddress);

        // Step 2: Deploy TREX Implementation Authority
        implementationAuthoritySetup = ImplementationAuthorityHelper.deploy(isReference);

        // Step 3: Deploy TREX Factory and link everything
        trexFactory =
            TREXFactoryHelper.deploy(implementationAuthoritySetup.implementationAuthority, onchainidSetup.idFactory);

        // Transfer ownership to deployer after linking is complete
        Ownable(address(implementationAuthoritySetup.implementationAuthority)).transferOwnership(deployerAddress);
        Ownable(address(trexFactory)).transferOwnership(deployerAddress);
        Ownable(address(onchainidSetup.idFactory)).transferOwnership(deployerAddress);

        // common identities for test addresses (alice, bob, charlie)
        vm.startPrank(deployerAddress);
        aliceIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(alice, "alice-salt"));
        bobIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(bob, "bob-salt"));
        charlieIdentity = IIdentity(onchainidSetup.idFactory.createIdentity(charlie, "charlie-salt"));
        vm.stopPrank();
    }

    /// @notice Returns the TREX Implementation Authority contract
    function getTREXImplementationAuthority() public view returns (TREXImplementationAuthority) {
        return implementationAuthoritySetup.implementationAuthority;
    }

    /// @notice Returns the Identity Factory (IdFactory) contract
    function getIdFactory() public view returns (IdFactory) {
        return onchainidSetup.idFactory;
    }

    /// @notice Returns the Identity implementation contract
    function getIdentityImplementation() public view returns (address) {
        return address(onchainidSetup.identityImplementation);
    }

    /// @notice Returns all TREX implementation contracts
    function getTREXImplementations()
        public
        view
        returns (address tokenImpl, address ctrImpl, address irImpl, address irsImpl, address tirImpl, address mcImpl)
    {
        return (
            address(implementationAuthoritySetup.implementations.token),
            address(implementationAuthoritySetup.implementations.claimTopicsRegistry),
            address(implementationAuthoritySetup.implementations.identityRegistry),
            address(implementationAuthoritySetup.implementations.identityRegistryStorage),
            address(implementationAuthoritySetup.implementations.trustedIssuersRegistry),
            address(implementationAuthoritySetup.implementations.modularCompliance)
        );
    }

    /// @notice Returns TREXContracts struct using current implementation addresses
    function getTREXContracts() public view returns (ITREXImplementationAuthority.TREXContracts memory) {
        (address tokenImpl, address ctrImpl, address irImpl, address irsImpl, address tirImpl, address mcImpl) =
            getTREXImplementations();
        return ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: tokenImpl,
            ctrImplementation: ctrImpl,
            irImplementation: irImpl,
            irsImplementation: irsImpl,
            tirImplementation: tirImpl,
            mcImplementation: mcImpl
        });
    }

}
