// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {AbstractModule} from '../AbstractModule.sol';

/// @title MaxBalanceModule
/// @notice Compliance module that enforces a maximum token balance per wallet.
/// The limit is configured per compliance contract via `setMaxBalance`.
contract MaxBalanceModule is AbstractModule {
    /// @dev compliance address => max balance allowed
    mapping(address => uint256) private _maxBalance;

    event MaxBalanceSet(address indexed compliance, uint256 maxBalance);

    /// @notice Sets the maximum balance allowed for wallets under this compliance.
    /// @param _max The maximum number of tokens a single wallet can hold.
    function setMaxBalance(uint256 _max) external onlyComplianceCall {
        _maxBalance[msg.sender] = _max;
        emit MaxBalanceSet(msg.sender, _max);
    }

    /// @notice Returns the configured max balance for a compliance contract.
    function getMaxBalance(address _compliance) external view returns (uint256) {
        return _maxBalance[_compliance];
    }

    /// @dev Checks that the transfer/mint amount does not exceed max balance in a single operation.
    function moduleCheck(address /*_from*/, address /*_to*/, uint256 _value, address _compliance) external view override returns (bool) {
        uint256 max = _maxBalance[_compliance];
        if (max == 0) return true;
        if (_value > max) return false;
        return true;
    }

    // solhint-disable-next-line no-empty-blocks
    function moduleTransferAction(address, address, uint256) external override onlyComplianceCall {}

    // solhint-disable-next-line no-empty-blocks
    function moduleMintAction(address, uint256) external override onlyComplianceCall {}

    // solhint-disable-next-line no-empty-blocks
    function moduleBurnAction(address, uint256) external override onlyComplianceCall {}

    function canComplianceBind(address) external pure override returns (bool) {
        return true;
    }

    function isPlugAndPlay() external pure override returns (bool) {
        return true;
    }

    function name() public pure override returns (string memory) {
        return 'MaxBalanceModule';
    }
}
