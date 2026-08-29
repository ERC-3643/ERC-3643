// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../compliance/modular/IModularCompliance.sol";
import "../registry/interface/IIdentityRegistry.sol";

// solhint-disable-next-line max-states-count
contract Token1155Storage {
    /// @dev ERC-1155 balances: tokenId => account => balance
    mapping(uint256 => mapping(address => uint256)) internal _balances;

    /// @dev ERC-1155 operator approvals
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    /// @dev Per-tokenId total supply
    mapping(uint256 => uint256) internal _totalSupply;

    /// @dev Token information
    string internal _tokenName;
    string internal _tokenSymbol;
    address internal _tokenOnchainID;
    string internal constant _TOKEN_VERSION = "4.1.3";

    /// @dev Per-tokenId URI
    mapping(uint256 => string) internal _tokenURIs;

    /// @dev Per-tokenId decimals
    mapping(uint256 => uint8) internal _tokenDecimals;

    /// @dev TokenId management
    mapping(uint256 => bool) internal _tokenIdExists;
    uint256 internal _nextTokenId;

    /// @dev Global address freeze
    mapping(address => bool) internal _frozen;

    /// @dev Per-tokenId partial freeze: tokenId => account => frozen amount
    mapping(uint256 => mapping(address => uint256)) internal _frozenTokens;

    /// @dev Per-tokenId pause
    mapping(uint256 => bool) internal _tokenIdPaused;

    /// @dev Per-tokenId compliance
    mapping(uint256 => IModularCompliance) internal _tokenCompliance;

    /// @dev Shared identity registry
    IIdentityRegistry internal _tokenIdentityRegistry;

    uint256[49] private __gap;
}
