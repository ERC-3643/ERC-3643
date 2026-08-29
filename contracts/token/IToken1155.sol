// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "../compliance/modular/IModularCompliance.sol";
import "../registry/interface/IIdentityRegistry.sol";

interface IToken1155 is IERC1155, IERC1155MetadataURI {

    // Errors
    error ZeroAddress();
    error EmptyString();
    error AlreadyInitialized();
    error TokenIdDoesNotExist(uint256 tokenId);
    error TokenIdIsPaused(uint256 tokenId);
    error TokenIdIsNotPaused(uint256 tokenId);
    error TokenIdAlreadyPaused(uint256 tokenId);
    error DecimalsOutOfRange(uint8 decimals);
    error InsufficientBalance(address account, uint256 tokenId, uint256 required, uint256 available);
    error InsufficientUnfrozenBalance(address account, uint256 tokenId, uint256 required, uint256 available);
    error FreezeAmountExceedsAvailable(address account, uint256 tokenId, uint256 amount, uint256 available);
    error UnfreezeAmountExceedsFrozen(address account, uint256 tokenId, uint256 amount, uint256 frozen);
    error WalletIsFrozen(address wallet);
    error IdentityNotVerified(address wallet);
    error TransferNotCompliant(address from, address to, uint256 amount);
    error CallerNotOwnerOrApproved(address caller);
    error ArrayLengthMismatch();
    error BurnExceedsBalance(address account, uint256 tokenId, uint256 amount, uint256 balance);
    error NoTokensToRecover(address wallet);
    error RecoveryKeyNotFound(address wallet);
    error ERC1155TransferToZeroAddress();
    error ERC1155ReceiverRejected();
    error ERC1155TransferToNonReceiver(address to);
    error SelfApproval();

    // Events

    event TokenIdCreated(uint256 indexed tokenId, uint8 decimals, address indexed compliance);
    event TokenComplianceSet(uint256 indexed tokenId, address indexed compliance);
    event UpdatedTokenInformation(string _newName, string _newSymbol, string _newVersion, address _newOnchainID);
    event IdentityRegistryAdded(address indexed _identityRegistry);
    event AddressFrozen(address indexed _userAddress, bool indexed _isFrozen, address indexed _owner);
    event TokensFrozen(address indexed _userAddress, uint256 indexed _tokenId, uint256 _amount);
    event TokensUnfrozen(address indexed _userAddress, uint256 indexed _tokenId, uint256 _amount);
    event TokenIdPaused(uint256 indexed tokenId, address indexed agent);
    event TokenIdUnpaused(uint256 indexed tokenId, address indexed agent);
    event RecoverySuccess(address _lostWallet, address _newWallet, address _investorOnchainID);

    // External (non-view, non-pure) functions

    function createTokenId(uint8 _decimals, address _compliance) external returns (uint256);
    function mint(address _to, uint256 _amount, uint256 _tokenId) external;
    function burn(address _userAddress, uint256 _amount, uint256 _tokenId) external;
    function forcedTransfer(address _from, address _to, uint256 _amount, uint256 _tokenId) external returns (bool);
    function setAddressFrozen(address _userAddress, bool _freeze) external;
    function freezePartialTokens(address _userAddress, uint256 _amount, uint256 _tokenId) external;
    function unfreezePartialTokens(address _userAddress, uint256 _amount, uint256 _tokenId) external;
    function pause(uint256 _tokenId) external;
    function unpause(uint256 _tokenId) external;
    function recoveryAddress(address _lostWallet, address _newWallet, address _investorOnchainID) external returns (bool);
    function setTokenCompliance(uint256 _tokenId, address _compliance) external;
    function setIdentityRegistry(address _identityRegistry) external;
    function setName(string calldata _name) external;
    function setSymbol(string calldata _symbol) external;
    function setOnchainID(address _onchainID) external;
    function setTokenURI(uint256 _tokenId, string calldata _uri) external;
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts, uint256 _tokenId) external;
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId) external;
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts,
        uint256 _tokenId
    ) external;
    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external;
    function batchFreezePartialTokens(
        address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId
    ) external;
    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId
    ) external;

    // External view functions

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function onchainID() external view returns (address);
    function identityRegistry() external view returns (IIdentityRegistry);
    function tokenCompliance(uint256 _tokenId) external view returns (IModularCompliance);
    function totalSupply(uint256 _tokenId) external view returns (uint256);
    function decimals(uint256 _tokenId) external view returns (uint8);
    function isFrozen(address _userAddress) external view returns (bool);
    function getFrozenTokens(address _userAddress, uint256 _tokenId) external view returns (uint256);
    function paused(uint256 _tokenId) external view returns (bool);
    function tokenIdExists(uint256 _tokenId) external view returns (bool);
    function getTokenIdCount() external view returns (uint256);

    // External pure functions

    function version() external pure returns (string memory);
}
