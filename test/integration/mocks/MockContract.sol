// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

contract MockContract {

    address _irRegistry;
    address _compliance;

    function identityRegistry() public view returns (address) {
        if (_irRegistry != address(0)) {
            return _irRegistry;
        } else {
            return address(this);
        }
    }

    function setCompliance(address complianceAddress) public {
        _compliance = complianceAddress;
    }

    function compliance() public view returns (address) {
        return _compliance;
    }

}
