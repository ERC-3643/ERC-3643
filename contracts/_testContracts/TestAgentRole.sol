// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "../roles/AgentRole.sol";

/// @notice Test contract that inherits from AgentRole to test the onlyAgent modifier
contract TestAgentRole is AgentRole {

    function callOnlyAgent() external onlyAgent {
        // Empty function to test the onlyAgent modifier
    }

}
