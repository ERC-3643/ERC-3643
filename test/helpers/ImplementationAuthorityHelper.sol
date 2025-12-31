// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ITREXImplementationAuthority } from "contracts/proxy/authority/ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";
import { ClaimTopicsRegistry } from "contracts/registry/implementation/ClaimTopicsRegistry.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import { IdentityRegistryStorage } from "contracts/registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "contracts/registry/implementation/TrustedIssuersRegistry.sol";
import { Token } from "contracts/token/Token.sol";

/// @notice Helper library for deploying and configuring TREX Implementation Authority
/// @dev Handles deploying all implementations and registering them with the IA
library ImplementationAuthorityHelper {

    struct ImplementationContracts {
        ClaimTopicsRegistry claimTopicsRegistry;
        TrustedIssuersRegistry trustedIssuersRegistry;
        IdentityRegistryStorage identityRegistryStorage;
        IdentityRegistry identityRegistry;
        ModularCompliance modularCompliance;
        Token token;
    }

    struct ImplementationAuthoritySetup {
        ImplementationContracts implementations;
        TREXImplementationAuthority implementationAuthority;
    }

    /// @notice Deploys all TREX implementation contracts
    function _deployImplementations() private returns (ImplementationContracts memory implementations) {
        implementations.claimTopicsRegistry = new ClaimTopicsRegistry();
        implementations.trustedIssuersRegistry = new TrustedIssuersRegistry();
        implementations.identityRegistryStorage = new IdentityRegistryStorage();
        implementations.identityRegistry = new IdentityRegistry();
        implementations.modularCompliance = new ModularCompliance();
        implementations.token = new Token();
    }

    /// @notice Deploys and configures TREX Implementation Authority with all implementations
    /// @param isReference Whether this is the reference (main) implementation authority
    /// @return setup Struct containing Implementation Authority and all implementations
    function deploy(bool isReference) internal returns (ImplementationAuthoritySetup memory setup) {
        // Deploy all implementation contracts
        setup.implementations = _deployImplementations();

        // Deploy TREX Implementation Authority
        setup.implementationAuthority = new TREXImplementationAuthority(isReference, address(0), address(0));

        // Configure version
        ITREXImplementationAuthority.Version memory version =
            ITREXImplementationAuthority.Version({ major: 4, minor: 0, patch: 0 });

        // Create contracts struct
        ITREXImplementationAuthority.TREXContracts memory contracts = ITREXImplementationAuthority.TREXContracts({
            tokenImplementation: address(setup.implementations.token),
            ctrImplementation: address(setup.implementations.claimTopicsRegistry),
            irImplementation: address(setup.implementations.identityRegistry),
            irsImplementation: address(setup.implementations.identityRegistryStorage),
            tirImplementation: address(setup.implementations.trustedIssuersRegistry),
            mcImplementation: address(setup.implementations.modularCompliance)
        });

        // Register and use version
        setup.implementationAuthority.addAndUseTREXVersion(version, contracts);
    }

}
