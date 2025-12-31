// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { TREXFactory } from "../factory/TREXFactory.sol";

/// @notice Test contract that inherits from TREXFactory to expose _deploy for testing
contract TestTREXFactory is TREXFactory {

    constructor(address implementationAuthority_, address idFactory_)
        TREXFactory(implementationAuthority_, idFactory_)
    { }

    /// @notice Exposes _deploy for testing
    function testDeploy(string memory salt, bytes memory bytecode) external returns (address) {
        return _deploy(salt, bytecode);
    }

}

