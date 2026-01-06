// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IdFactory } from "@onchain-id/solidity/contracts/factory/IdFactory.sol";
import { TREXFactory } from "contracts/factory/TREXFactory.sol";
import { TREXImplementationAuthority } from "contracts/proxy/authority/TREXImplementationAuthority.sol";

/// @notice Helper library for deploying TREX Factory and linking it with everything
/// @dev Deploys TREX Factory and creates bidirectional links with IA and Identity Factory
library TREXFactoryHelper {

    /// @notice Deploys TREX Factory and links it with Implementation Authority and Identity Factory
    /// @param implementationAuthority The TREX Implementation Authority contract
    /// @param identityFactory The Identity Factory (IdFactory) contract
    /// @param create3Factory The Create3Factory contract address
    /// @return factory The deployed TREX Factory
    function deploy(
        TREXImplementationAuthority implementationAuthority,
        IdFactory identityFactory,
        address create3Factory
    ) internal returns (TREXFactory factory) {
        // Deploy TREX Factory
        factory = new TREXFactory(address(implementationAuthority), address(identityFactory), create3Factory);

        // Link TREX Factory to Implementation Authority (bidirectional)
        implementationAuthority.setTREXFactory(address(factory));

        // Link TREX Factory to Identity Factory (bidirectional)
        identityFactory.addTokenFactory(address(factory));
    }

}
