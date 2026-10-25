// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

contract AlwaysValidClaimIssuer {
    function isClaimValid(address, uint256, bytes calldata, bytes calldata) external pure returns (bool) {
        return true;
    }
}

/// @dev non ONCHAINID identity answering every claim lookup with the same tuple, whatever the claim id
contract ForgedIdentity {
    uint256 internal immutable _topic;
    address internal immutable _issuer;

    constructor(uint256 topic, address issuer) {
        _topic = topic;
        _issuer = issuer;
    }

    function getClaim(bytes32)
        external
        view
        returns (uint256, uint256, address, bytes memory, bytes memory, string memory)
    {
        return (_topic, 1, _issuer, "", "", "");
    }
}
