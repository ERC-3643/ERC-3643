// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "../token/Token.sol";

/// This contract inherits from Token to expose internal functions as public functions
contract TestTokenInternal is Token {

    function exposeTransfer(address _from, address _to, uint256 _amount) external {
        _transfer(_from, _to, _amount);
    }

    function exposeMint(address _userAddress, uint256 _amount) external {
        _mint(_userAddress, _amount);
    }

    function exposeBurn(address _userAddress, uint256 _amount) external {
        _burn(_userAddress, _amount);
    }

    function exposeApprove(address _owner, address _spender, uint256 _amount) external {
        _approve(_owner, _spender, _amount);
    }

}
