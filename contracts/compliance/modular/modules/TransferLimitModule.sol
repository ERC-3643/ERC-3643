// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {AbstractModule} from '../AbstractModule.sol';

/// @title TransferLimitModule
/// @notice Compliance module that enforces a maximum amount per single transfer.
/// The limit is configured per compliance contract via `setTransferLimit`.
contract TransferLimitModule is AbstractModule {
    /// @dev compliance address => max transfer amount
    mapping(address => uint256) private _transferLimit;

    event TransferLimitSet(address indexed compliance, uint256 limit);

    /// @notice Sets the maximum amount allowed per transfer under this compliance.
    /// @param _limit The maximum tokens transferable in a single operation.
    function setTransferLimit(uint256 _limit) external onlyComplianceCall {
        _transferLimit[msg.sender] = _limit;
        emit TransferLimitSet(msg.sender, _limit);
    }

    /// @notice Returns the configured transfer limit for a compliance contract.
    function getTransferLimit(address _compliance) external view returns (uint256) {
        return _transferLimit[_compliance];
    }

    /// @dev Checks that transfer amount <= transferLimit.
    function moduleCheck(address /*_from*/, address /*_to*/, uint256 _value, address _compliance) external view override returns (bool) {
        uint256 limit = _transferLimit[_compliance];
        if (limit == 0) return true;
        return _value <= limit;
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
        return 'TransferLimitModule';
    }
}
