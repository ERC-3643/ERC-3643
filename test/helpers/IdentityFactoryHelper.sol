// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Identity } from "@onchain-id/solidity/contracts/Identity.sol";
import { IdFactory } from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";

/// @notice Helper library for deploying ONCHAINID Identity Factory infrastructure
/// @dev Handles Identity implementation + IdFactory (ImplementationAuthority is used internally)
library IdentityFactoryHelper {

    struct ONCHAINIDSetup {
        Identity identityImplementation;
        IdFactory idFactory;
    }

    /// @notice Deploys complete Identity Factory infrastructure
    /// @param managementKey The management key for the identity implementation
    /// @return setup Struct containing ONCHAINID setup
    function deploy(address managementKey) internal returns (ONCHAINIDSetup memory setup) {
        // Deploy Identity implementation
        setup.identityImplementation = new Identity(managementKey, true);

        // Deploy Implementation Authority (for Identity proxies) - used internally only
        ImplementationAuthority implementationAuthority =
            new ImplementationAuthority(address(setup.identityImplementation));

        // Deploy Identity Factory
        setup.idFactory = new IdFactory(address(implementationAuthority));
    }

}
