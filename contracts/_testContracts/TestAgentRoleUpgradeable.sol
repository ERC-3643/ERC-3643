// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "../roles/AgentRoleUpgradeable.sol";

/// @notice Test contract that inherits from AgentRoleUpgradeable to test the onlyAgent modifier
contract TestAgentRoleUpgradeable is AgentRoleUpgradeable {

    function initialize() external initializer {
        __Ownable_init();
    }

    function callOnlyAgent() external onlyAgent {
        // Empty function to test the onlyAgent modifier
    }

}
