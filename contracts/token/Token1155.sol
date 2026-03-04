// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./IToken1155.sol";
import "./Token1155Storage.sol";
import "../roles/AgentRoleUpgradeable.sol";
import "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// solhint-disable code-complexity, ordering
contract Token1155 is IToken1155, AgentRoleUpgradeable, Token1155Storage {
    using Address for address;

    // Modifiers

    modifier tokenIdMustExist(uint256 _tokenId) {
        if (!_tokenIdExists[_tokenId]) revert TokenIdDoesNotExist(_tokenId);
        _;
    }

    modifier whenTokenIdNotPaused(uint256 _tokenId) {
        if (_tokenIdPaused[_tokenId]) revert TokenIdIsPaused(_tokenId);
        _;
    }

    modifier whenTokenIdPaused(uint256 _tokenId) {
        if (!_tokenIdPaused[_tokenId]) revert TokenIdIsNotPaused(_tokenId);
        _;
    }

    // Initializer

    function init(
        address _identityRegistry,
        string memory _name,
        string memory _symbol,
        address _onchainID
    ) external initializer {
        if (owner() != address(0)) revert AlreadyInitialized();
        if (_identityRegistry == address(0)) revert ZeroAddress();
        if (
            keccak256(abi.encode(_name)) == keccak256(abi.encode(""))
            || keccak256(abi.encode(_symbol)) == keccak256(abi.encode(""))
        ) revert EmptyString();
        __Ownable_init();
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenOnchainID = _onchainID;
        _tokenIdentityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryAdded(_identityRegistry);
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _TOKEN_VERSION, _tokenOnchainID);
    }

    // Token ID management

    function createTokenId(uint8 _decimals, address _compliance) external override onlyOwner returns (uint256) {
        if (_compliance == address(0)) revert ZeroAddress();
        if (_decimals > 18) revert DecimalsOutOfRange(_decimals);
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        _tokenIdExists[tokenId] = true;
        _tokenDecimals[tokenId] = _decimals;
        _tokenIdPaused[tokenId] = true;
        _tokenCompliance[tokenId] = IModularCompliance(_compliance);
        IModularCompliance(_compliance).bindToken(address(this));
        emit TokenIdCreated(tokenId, _decimals, _compliance);
        return tokenId;
    }

    // ERC-1155 standard functions

    function balanceOf(address _account, uint256 _id) public view override returns (uint256) {
        if (_account == address(0)) revert ZeroAddress();
        return _balances[_id][_account];
    }

    function balanceOfBatch(
        address[] calldata _accounts,
        uint256[] calldata _ids
    ) external view override returns (uint256[] memory) {
        if (_accounts.length != _ids.length) revert ArrayLengthMismatch();
        uint256[] memory batchBalances = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            batchBalances[i] = balanceOf(_accounts[i], _ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(address _operator, bool _approved) external override {
        if (msg.sender == _operator) revert SelfApproval();
        _operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _account, address _operator) public view override returns (bool) {
        return _operatorApprovals[_account][_operator];
    }

    // solhint-disable-next-line function-max-lines
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override tokenIdMustExist(_id) whenTokenIdNotPaused(_id) {
        if (_from != msg.sender && !isApprovedForAll(_from, msg.sender)) {
            revert CallerNotOwnerOrApproved(msg.sender);
        }
        _validateAndTransfer(_from, _to, _id, _amount);
        emit TransferSingle(msg.sender, _from, _to, _id, _amount);
        _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _amount, _data);
    }

    // solhint-disable-next-line function-max-lines
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override {
        if (_ids.length != _amounts.length) revert ArrayLengthMismatch();
        if (_from != msg.sender && !isApprovedForAll(_from, msg.sender)) {
            revert CallerNotOwnerOrApproved(msg.sender);
        }
        for (uint256 i = 0; i < _ids.length; i++) {
            if (!_tokenIdExists[_ids[i]]) revert TokenIdDoesNotExist(_ids[i]);
            if (_tokenIdPaused[_ids[i]]) revert TokenIdIsPaused(_ids[i]);
            _validateAndTransfer(_from, _to, _ids[i], _amounts[i]);
        }
        emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
        _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _amounts, _data);
    }

    function uri(uint256 _id) external view override returns (string memory) {
        return _tokenURIs[_id];
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    // Agent functions

    function mint(address _to, uint256 _amount, uint256 _tokenId) public override onlyAgent tokenIdMustExist(_tokenId) {
        if (!_tokenIdentityRegistry.isVerified(_to)) revert IdentityNotVerified(_to);
        if (!_tokenCompliance[_tokenId].canTransfer(address(0), _to, _amount)) {
            revert TransferNotCompliant(address(0), _to, _amount);
        }
        _balances[_tokenId][_to] += _amount;
        _totalSupply[_tokenId] += _amount;
        emit TransferSingle(msg.sender, address(0), _to, _tokenId, _amount);
        _tokenCompliance[_tokenId].created(_to, _amount);
    }

    function burn(address _userAddress, uint256 _amount, uint256 _tokenId) public override onlyAgent tokenIdMustExist(_tokenId) {
        uint256 balance = balanceOf(_userAddress, _tokenId);
        if (balance < _amount) revert BurnExceedsBalance(_userAddress, _tokenId, _amount, balance);
        uint256 freeBalance = balance - _frozenTokens[_tokenId][_userAddress];
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - freeBalance;
            _frozenTokens[_tokenId][_userAddress] -= tokensToUnfreeze;
            emit TokensUnfrozen(_userAddress, _tokenId, tokensToUnfreeze);
        }
        _balances[_tokenId][_userAddress] -= _amount;
        _totalSupply[_tokenId] -= _amount;
        emit TransferSingle(msg.sender, _userAddress, address(0), _tokenId, _amount);
        _tokenCompliance[_tokenId].destroyed(_userAddress, _amount);
    }

    // solhint-disable-next-line function-max-lines
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _tokenId
    ) public override onlyAgent tokenIdMustExist(_tokenId) returns (bool) {
        uint256 balance = balanceOf(_from, _tokenId);
        if (balance < _amount) {
            revert InsufficientBalance(_from, _tokenId, _amount, balance);
        }
        uint256 freeBalance = balance - _frozenTokens[_tokenId][_from];
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - freeBalance;
            _frozenTokens[_tokenId][_from] -= tokensToUnfreeze;
            emit TokensUnfrozen(_from, _tokenId, tokensToUnfreeze);
        }
        if (!_tokenIdentityRegistry.isVerified(_to)) revert IdentityNotVerified(_to);
        _balances[_tokenId][_from] -= _amount;
        _balances[_tokenId][_to] += _amount;
        emit TransferSingle(msg.sender, _from, _to, _tokenId, _amount);
        _tokenCompliance[_tokenId].transferred(_from, _to, _amount);
        return true;
    }

    function setAddressFrozen(address _userAddress, bool _freeze) public override onlyAgent {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    function freezePartialTokens(
        address _userAddress, uint256 _amount, uint256 _tokenId
    ) public override onlyAgent tokenIdMustExist(_tokenId) {
        uint256 balance = balanceOf(_userAddress, _tokenId);
        uint256 alreadyFrozen = _frozenTokens[_tokenId][_userAddress];
        if (balance < alreadyFrozen + _amount) {
            revert FreezeAmountExceedsAvailable(_userAddress, _tokenId, _amount, balance - alreadyFrozen);
        }
        _frozenTokens[_tokenId][_userAddress] += _amount;
        emit TokensFrozen(_userAddress, _tokenId, _amount);
    }

    function unfreezePartialTokens(
        address _userAddress, uint256 _amount, uint256 _tokenId
    ) public override onlyAgent tokenIdMustExist(_tokenId) {
        uint256 frozen = _frozenTokens[_tokenId][_userAddress];
        if (frozen < _amount) {
            revert UnfreezeAmountExceedsFrozen(_userAddress, _tokenId, _amount, frozen);
        }
        _frozenTokens[_tokenId][_userAddress] -= _amount;
        emit TokensUnfrozen(_userAddress, _tokenId, _amount);
    }

    function pause(uint256 _tokenId) external override onlyAgent tokenIdMustExist(_tokenId) whenTokenIdNotPaused(_tokenId) {
        _tokenIdPaused[_tokenId] = true;
        emit TokenIdPaused(_tokenId, msg.sender);
    }

    function unpause(uint256 _tokenId) external override onlyAgent tokenIdMustExist(_tokenId) whenTokenIdPaused(_tokenId) {
        _tokenIdPaused[_tokenId] = false;
        emit TokenIdUnpaused(_tokenId, msg.sender);
    }

    // solhint-disable-next-line function-max-lines
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external override onlyAgent returns (bool) {
        bool hasTokens = false;
        for (uint256 i = 0; i < _nextTokenId; i++) {
            if (balanceOf(_lostWallet, i) > 0) {
                hasTokens = true;
                break;
            }
        }
        if (!hasTokens) revert NoTokensToRecover(_lostWallet);
        IIdentity _onchainID = IIdentity(_investorOnchainID);
        bytes32 _key = keccak256(abi.encode(_newWallet));
        if (!_onchainID.keyHasPurpose(_key, 1)) revert RecoveryKeyNotFound(_newWallet);
        _tokenIdentityRegistry.registerIdentity(
            _newWallet,
            _onchainID,
            _tokenIdentityRegistry.investorCountry(_lostWallet)
        );
        for (uint256 i = 0; i < _nextTokenId; i++) {
            uint256 bal = balanceOf(_lostWallet, i);
            if (bal > 0) {
                forcedTransfer(_lostWallet, _newWallet, bal, i);
                uint256 frozenAmt = _frozenTokens[i][_lostWallet];
                if (frozenAmt > 0) {
                    freezePartialTokens(_newWallet, frozenAmt, i);
                }
            }
        }
        if (_frozen[_lostWallet]) {
            setAddressFrozen(_newWallet, true);
        }
        _tokenIdentityRegistry.deleteIdentity(_lostWallet);
        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }

    // Owner functions

    function setTokenCompliance(
        uint256 _tokenId, address _compliance
    ) external override onlyOwner tokenIdMustExist(_tokenId) {
        if (_compliance == address(0)) revert ZeroAddress();
        if (address(_tokenCompliance[_tokenId]) != address(0)) {
            _tokenCompliance[_tokenId].unbindToken(address(this));
        }
        _tokenCompliance[_tokenId] = IModularCompliance(_compliance);
        IModularCompliance(_compliance).bindToken(address(this));
        emit TokenComplianceSet(_tokenId, _compliance);
    }

    function setIdentityRegistry(address _identityRegistry) external override onlyOwner {
        _tokenIdentityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryAdded(_identityRegistry);
    }

    function setName(string calldata _name) external override onlyOwner {
        if (keccak256(abi.encode(_name)) == keccak256(abi.encode(""))) revert EmptyString();
        _tokenName = _name;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setSymbol(string calldata _symbol) external override onlyOwner {
        if (keccak256(abi.encode(_symbol)) == keccak256(abi.encode(""))) revert EmptyString();
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setOnchainID(address _onchainID) external override onlyOwner {
        _tokenOnchainID = _onchainID;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setTokenURI(uint256 _tokenId, string calldata _uri) external override onlyOwner tokenIdMustExist(_tokenId) {
        _tokenURIs[_tokenId] = _uri;
        emit URI(_uri, _tokenId);
    }

    // View functions

    function name() external view override returns (string memory) {
        return _tokenName;
    }

    function symbol() external view override returns (string memory) {
        return _tokenSymbol;
    }

    function onchainID() external view override returns (address) {
        return _tokenOnchainID;
    }

    function version() external pure override returns (string memory) {
        return _TOKEN_VERSION;
    }

    function identityRegistry() external view override returns (IIdentityRegistry) {
        return _tokenIdentityRegistry;
    }

    function tokenCompliance(uint256 _tokenId) external view override returns (IModularCompliance) {
        return _tokenCompliance[_tokenId];
    }

    function totalSupply(uint256 _tokenId) external view override returns (uint256) {
        return _totalSupply[_tokenId];
    }

    function decimals(uint256 _tokenId) external view override returns (uint8) {
        return _tokenDecimals[_tokenId];
    }

    function isFrozen(address _userAddress) external view override returns (bool) {
        return _frozen[_userAddress];
    }

    function getFrozenTokens(address _userAddress, uint256 _tokenId) external view override returns (uint256) {
        return _frozenTokens[_tokenId][_userAddress];
    }

    function paused(uint256 _tokenId) external view override returns (bool) {
        return _tokenIdPaused[_tokenId];
    }

    function tokenIdExists(uint256 _tokenId) external view override returns (bool) {
        return _tokenIdExists[_tokenId];
    }

    function getTokenIdCount() external view override returns (uint256) {
        return _nextTokenId;
    }

    // Batch operations

    function batchMint(address[] calldata _toList, uint256[] calldata _amounts, uint256 _tokenId) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            mint(_toList[i], _amounts[i], _tokenId);
        }
    }

    function batchBurn(
        address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            burn(_userAddresses[i], _amounts[i], _tokenId);
        }
    }

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts,
        uint256 _tokenId
    ) external override {
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i], _tokenId);
        }
    }

    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
        }
    }

    function batchFreezePartialTokens(
        address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            freezePartialTokens(_userAddresses[i], _amounts[i], _tokenId);
        }
    }

    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses, uint256[] calldata _amounts, uint256 _tokenId
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i], _tokenId);
        }
    }

    // Internal functions

    function _validateAndTransfer(address _from, address _to, uint256 _id, uint256 _amount) internal {
        if (_to == address(0)) revert ERC1155TransferToZeroAddress();
        if (_frozen[_from]) revert WalletIsFrozen(_from);
        if (_frozen[_to]) revert WalletIsFrozen(_to);
        uint256 available = balanceOf(_from, _id) - _frozenTokens[_id][_from];
        if (_amount > available) {
            revert InsufficientUnfrozenBalance(_from, _id, _amount, available);
        }
        if (!_tokenIdentityRegistry.isVerified(_to)) revert IdentityNotVerified(_to);
        if (!_tokenCompliance[_id].canTransfer(_from, _to, _amount)) {
            revert TransferNotCompliant(_from, _to, _amount);
        }
        _balances[_id][_from] -= _amount;
        _balances[_id][_to] += _amount;
        _tokenCompliance[_id].transferred(_from, _to, _amount);
    }

    function _doSafeTransferAcceptanceCheck(
        address _operator,
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) private {
        if (_to.isContract()) {
            try IERC1155Receiver(_to).onERC1155Received(_operator, _from, _id, _amount, _data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert ERC1155ReceiverRejected();
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155TransferToNonReceiver(_to);
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address _operator,
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) private {
        if (_to.isContract()) {
            try IERC1155Receiver(_to).onERC1155BatchReceived(_operator, _from, _ids, _amounts, _data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert ERC1155ReceiverRejected();
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155TransferToNonReceiver(_to);
            }
        }
    }
}
