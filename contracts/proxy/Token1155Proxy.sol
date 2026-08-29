// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./AbstractProxy.sol";

contract Token1155Proxy is AbstractProxy {

    error ZeroAddress();
    error EmptyString();
    error NoImplementation();
    error InitializationFailed();

    constructor(
        address implementationAuthority,
        address _identityRegistry,
        string memory _name,
        string memory _symbol,
        address _onchainID
    ) {
        if (implementationAuthority == address(0) || _identityRegistry == address(0)) revert ZeroAddress();
        if (
            keccak256(abi.encode(_name)) == keccak256(abi.encode(""))
            || keccak256(abi.encode(_symbol)) == keccak256(abi.encode(""))
        ) revert EmptyString();
        _storeImplementationAuthority(implementationAuthority);
        emit ImplementationAuthoritySet(implementationAuthority);

        address logic = ITREXImplementationAuthority(getImplementationAuthority()).getToken1155Implementation();
        if (logic == address(0)) revert NoImplementation();

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = logic.delegatecall(
            abi.encodeWithSignature(
                "init(address,string,string,address)",
                _identityRegistry,
                _name,
                _symbol,
                _onchainID
            )
        );
        if (!success) revert InitializationFailed();
    }

    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        address logic = ITREXImplementationAuthority(getImplementationAuthority()).getToken1155Implementation();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(sub(gas(), 10000), logic, 0x0, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
                case 0 {
                    revert(0, retSz)
                }
                default {
                    return(0, retSz)
                }
        }
    }
}
