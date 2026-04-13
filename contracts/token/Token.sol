// SPDX-License-Identifier: GPL-3.0
//
//                                             :+#####%%%%%%%%%%%%%%+
//                                         .-*@@@%+.:+%@@@@@%%#***%@@%=
//                                     :=*%@@@#=.      :#@@%       *@@@%=
//                       .-+*%@%*-.:+%@@@@@@+.     -*+:  .=#.       :%@@@%-
//                   :=*@@@@%%@@@@@@@@@%@@@-   .=#@@@%@%=             =@@@@#.
//             -=+#%@@%#*=:.  :%@@@@%.   -*@@#*@@@@@@@#=:-              *@@@@+
//            =@@%=:.     :=:   *@@@@@%#-   =%*%@@@@#+-.        =+       :%@@@%-
//           -@@%.     .+@@@     =+=-.         @@#-           +@@@%-       =@@@@%:
//          :@@@.    .+@@#%:                   :    .=*=-::.-%@@@+*@@=       +@@@@#.
//          %@@:    +@%%*                         =%@@@@@@@@@@@#.  .*@%-       +@@@@*.
//         #@@=                                .+@@@@%:=*@@@@@-      :%@%:      .*@@@@+
//        *@@*                                +@@@#-@@%-:%@@*          +@@#.      :%@@@@-
//       -@@%           .:-=++*##%%%@@@@@@@@@@@@*. :@+.@@@%:            .#@@+       =@@@@#:
//      .@@@*-+*#%%%@@@@@@@@@@@@@@@@%%#**@@%@@@.   *@=*@@#                :#@%=      .#@@@@#-
//      -%@@@@@@@@@@@@@@@*+==-:-@@@=    *@# .#@*-=*@@@@%=                 -%@@@*       =@@@@@%-
//         -+%@@@#.   %@%%=   -@@:+@: -@@*    *@@*-::                   -%@@%=.         .*@@@@@#
//            *@@@*  +@* *@@##@@-  #@*@@+    -@@=          .         :+@@@#:           .-+@@@%+-
//             +@@@%*@@:..=@@@@*   .@@@*   .#@#.       .=+-       .=%@@@*.         :+#@@@@*=:
//              =@@@@%@@@@@@@@@@@@@@@@@@@@@@%-      :+#*.       :*@@@%=.       .=#@@@@%+:
//               .%@@=                 .....    .=#@@+.       .#@@@*:       -*%@@@@%+.
//                 +@@#+===---:::...         .=%@@*-         +@@@+.      -*@@@@@%+.
//                  -@@@@@@@@@@@@@@@@@@@@@@%@@@@=          -@@@+      -#@@@@@#=.
//                    ..:::---===+++***###%%%@@@#-       .#@@+     -*@@@@@#=.
//                                           @@@@@@+.   +@@*.   .+@@@@@%=.
//                                          -@@@@@=   =@@%:   -#@@@@%+.
//                                          +@@@@@. =@@@=  .+@@@@@*:
//                                          #@@@@#:%@@#. :*@@@@#-
//                                          @@@@@%@@@= :#@@@@+.
//                                         :@@@@@@@#.:#@@@%-
//                                         +@@@@@@-.*@@@*:
//                                         #@@@@#.=@@@+.
//                                         @@@@+-%@%=
//                                        :@@@#%@%=
//                                        +@@@@%-
//                                        :#%%=
//

/**
 *     NOTICE
 *
 *     The T-REX software is licensed under a proprietary license or the GPL v.3.
 *     If you choose to receive it under the GPL v.3 license, the following applies:
 *     T-REX is a suite of smart contracts implementing the ERC-3643 standard and
 *     developed by Tokeny to manage and transfer financial assets on EVM blockchains
 *
 *     Copyright (C) 2025, Tokeny sàrl.
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    ContextUpgradeable,
    ERC2771ContextUpgradeable
} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {
    ERC20PermitUpgradeable,
    ERC20Upgradeable,
    IERC20Permit
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ERC3643EventsLib } from "../ERC-3643/ERC3643EventsLib.sol";
import { IERC3643 } from "../ERC-3643/IERC3643.sol";
import { IERC3643Compliance } from "../ERC-3643/IERC3643Compliance.sol";
import { IERC3643IdentityRegistry } from "../ERC-3643/IERC3643IdentityRegistry.sol";
import { ErrorsLib } from "../libraries/ErrorsLib.sol";
import { EventsLib } from "../libraries/EventsLib.sol";
import { IIdentityRegistry } from "../registry/interface/IIdentityRegistry.sol";
import { AgentRole } from "../roles/AgentRole.sol";
import { IERC173 } from "../roles/IERC173.sol";
import { IToken } from "./IToken.sol";
import { TokenRoles } from "./TokenStructs.sol";

contract Token is
    ERC20PermitUpgradeable,
    PausableUpgradeable,
    AccessManagedUpgradeable,
    OwnableUpgradeable,
    ERC2771ContextUpgradeable,
    AgentRole,
    IToken,
    IERC165
{

    string internal constant VERSION = "5.0.0";

    struct FrozenStatus {
        bool addressFrozen;
        uint256 amount;
    }

    /// @custom:storage-location erc7201:token.storage.main
    struct TokenStorage {
        uint8 decimals;
        address onchainId;
        IERC3643Compliance compliance;
        IERC3643IdentityRegistry identityRegistry;
        address trustedForwarder;

        mapping(address user => FrozenStatus) frozenStatus;
        mapping(address spender => bool) defaultAllowances;
        mapping(address user => bool) defaultAllowanceOptOuts;

        mapping(address agent => TokenRoles) agentsRestrictions;
    }

    // keccak256(abi.encode(uint256(keccak256("token.storage.main")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant TOKEN_STORAGE_LOCATION =
        0x3eb201768b0b55c18fa93955aeb38c6bf0f381d8227d53e1b0e5b066883d4e00;

    bytes32 private constant ERC20_STORAGE_LOCATION =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
    bytes32 private constant EIP712_STORAGE_LOCATION =
        0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100;

    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    /// @dev the constructor initiates the token contract
    /// msg.sender is set automatically as the owner of the smart contract
    /// @param name the name of the token
    /// @param symbol the symbol of the token
    /// @param tokenDecimals the decimals of the token
    /// @param identityRegistryAddress the address of the Identity registry linked to the token
    /// @param complianceAddress the address of the compliance contract linked to the token
    /// @param onchainIdAddress the address of the onchainID of the token
    ///     onchainID can be zero address if not set, can be set later by the owner
    /// emits an `UpdatedTokenInformation` event
    /// emits an `IdentityRegistryAdded` event
    /// emits a `ComplianceAdded` event
    function init(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        address identityRegistryAddress,
        address complianceAddress,
        address onchainIdAddress,
        address accessManagerAddress
    ) external initializer {
        require(identityRegistryAddress != address(0) && complianceAddress != address(0), ErrorsLib.ZeroAddress());
        require(bytes(name).length > 0 && bytes(symbol).length > 0, ErrorsLib.EmptyString());
        require(tokenDecimals <= 18, ErrorsLib.DecimalsOutOfRange(tokenDecimals));

        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Pausable_init();
        __AccessManaged_init(accessManagerAddress);
        __Ownable_init(accessManagerAddress);

        TokenStorage storage s = _tokenStorage();
        s.decimals = tokenDecimals;
        s.onchainId = onchainIdAddress;

        _setIdentityRegistry(identityRegistryAddress);
        _setCompliance(complianceAddress);
        _emitUpdatedTokenInformation();

        _pause();
    }

    /* ----- Main token properties ----- */

    /// @inheritdoc IERC3643
    function setName(string calldata name) external override restricted {
        require(bytes(name).length > 0, ErrorsLib.EmptyString());
        _erc20Storage()._name = name;
        _eip712Storage()._name = name;
        _eip712Storage()._hashedName = 0;
        _emitUpdatedTokenInformation();
    }

    /// @inheritdoc IERC3643
    function setSymbol(string calldata symbol) external override restricted {
        require(bytes(symbol).length > 0, ErrorsLib.EmptyString());
        _erc20Storage()._symbol = symbol;
        _emitUpdatedTokenInformation();
    }

    /// @inheritdoc IERC3643
    /// @dev if _onchainID is set at zero address it means no ONCHAINID is bound to this token
    function setOnchainID(address onchainIdAddress) external override restricted {
        _tokenStorage().onchainId = onchainIdAddress;
        _emitUpdatedTokenInformation();
    }

    /// @inheritdoc IERC3643
    function setIdentityRegistry(address _identityRegistry) external override restricted {
        _setIdentityRegistry(_identityRegistry);
    }

    function _setIdentityRegistry(address _identityRegistry) internal {
        _tokenStorage().identityRegistry = IERC3643IdentityRegistry(_identityRegistry);
        emit ERC3643EventsLib.IdentityRegistryAdded(_identityRegistry);
    }

    /// @inheritdoc IERC3643
    function setCompliance(address _compliance) external override restricted {
        _setCompliance(_compliance);
    }

    function _setCompliance(address _compliance) internal {
        TokenStorage storage s = _tokenStorage();
        if (address(s.compliance) != address(0)) {
            s.compliance.unbindToken(address(this));
        }
        s.compliance = IERC3643Compliance(_compliance);
        s.compliance.bindToken(address(this));
        emit ERC3643EventsLib.ComplianceAdded(_compliance);
    }

    /// @inheritdoc IERC3643
    function onchainID() external view override returns (address) {
        return _tokenStorage().onchainId;
    }

    /// @inheritdoc IERC3643
    function identityRegistry() external view override returns (IERC3643IdentityRegistry) {
        return _tokenStorage().identityRegistry;
    }

    /// @inheritdoc IERC3643
    function compliance() external view override returns (IERC3643Compliance) {
        return _tokenStorage().compliance;
    }

    /// @inheritdoc IERC3643
    function version() public pure override returns (string memory) {
        return VERSION;
    }

    /* ----- Pause Functions ----- */

    /// @inheritdoc IERC3643
    function pause() external override restricted whenNotPaused {
        _pause();
    }

    /// @inheritdoc IERC3643
    function unpause() external override restricted whenPaused {
        _unpause();
    }

    /// @inheritdoc IERC3643
    function paused() public view override(PausableUpgradeable, IERC3643) returns (bool) {
        return super.paused();
    }

    /* ----- Minting & Burning Functions ----- */

    /// @inheritdoc IERC3643
    function mint(address to, uint256 amount) public override restricted {
        TokenStorage storage s = _tokenStorage();
        require(s.identityRegistry.isVerified(to), ErrorsLib.UnverifiedIdentity());
        require(s.compliance.canTransfer(address(0), to, amount), ErrorsLib.ComplianceNotFollowed());

        _mint(to, amount);
        s.compliance.created(to, amount);
    }

    /// @inheritdoc IERC3643
    function burn(address from, uint256 amount) public override restricted {
        uint256 balance = balanceOf(from);
        require(balance >= amount, ERC20InsufficientBalance(from, balance, amount));

        TokenStorage storage s = _tokenStorage();

        uint256 freeBalance = balance - s.frozenStatus[from].amount;
        if (amount > freeBalance) {
            uint256 tokensToUnfreeze = amount - freeBalance;
            s.frozenStatus[from].amount -= tokensToUnfreeze;
            emit ERC3643EventsLib.TokensUnfrozen(from, tokensToUnfreeze);
        }
        _burn(from, amount);
        s.compliance.destroyed(from, amount);
    }

    /// @inheritdoc IERC3643
    function batchMint(address[] calldata tos, uint256[] calldata amounts) external override {
        for (uint256 i = 0; i < tos.length; i++) {
            mint(tos[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external override {
        for (uint256 i = 0; i < froms.length; i++) {
            burn(froms[i], amounts[i]);
        }
    }

    /* ----- Freezing Functions ----- */

    /// @inheritdoc IERC3643
    function freezePartialTokens(address user, uint256 amount) public override restricted {
        TokenStorage storage s = _tokenStorage();
        uint256 balance = balanceOf(user);
        require(
            balance >= s.frozenStatus[user].amount + amount,
            IERC20Errors.ERC20InsufficientBalance(user, balance, amount)
        );
        s.frozenStatus[user].amount += amount;
        emit ERC3643EventsLib.TokensFrozen(user, amount);
    }

    /// @inheritdoc IERC3643
    function unfreezePartialTokens(address user, uint256 amount) public override restricted {
        TokenStorage storage s = _tokenStorage();

        require(
            s.frozenStatus[user].amount >= amount,
            ErrorsLib.AmountAboveFrozenTokens(amount, s.frozenStatus[user].amount)
        );
        s.frozenStatus[user].amount -= amount;
        emit ERC3643EventsLib.TokensUnfrozen(user, amount);
    }

    /// @inheritdoc IERC3643
    function setAddressFrozen(address user, bool freeze) public override restricted {
        _tokenStorage().frozenStatus[user].addressFrozen = freeze;

        emit ERC3643EventsLib.AddressFrozen(user, freeze, _msgSender());
    }

    /// @inheritdoc IERC3643
    function batchFreezePartialTokens(address[] calldata users, uint256[] calldata amounts) external {
        for (uint256 i = 0; i < users.length; i++) {
            freezePartialTokens(users[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchUnfreezePartialTokens(address[] calldata users, uint256[] calldata amounts) external override {
        for (uint256 i = 0; i < users.length; i++) {
            unfreezePartialTokens(users[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchSetAddressFrozen(address[] calldata users, bool[] calldata freezes) external override {
        for (uint256 i = 0; i < users.length; i++) {
            setAddressFrozen(users[i], freezes[i]);
        }
    }

    /// @inheritdoc IERC3643
    function isFrozen(address user) external view override returns (bool) {
        return _tokenStorage().frozenStatus[user].addressFrozen;
    }

    /// @inheritdoc IERC3643
    function getFrozenTokens(address user) external view override returns (uint256) {
        return _tokenStorage().frozenStatus[user].amount;
    }

    /* ----- Recovery Functions ----- */

    /// @inheritdoc IERC3643
    function recoveryAddress(address lostWallet, address newWallet, address investorOnchainId)
        external
        override
        restricted
        returns (bool)
    {
        TokenStorage storage s = _tokenStorage();

        uint256 investorTokens = balanceOf(lostWallet);
        require(investorTokens != 0, ErrorsLib.NoTokenToRecover());
        require(
            s.identityRegistry.contains(lostWallet) || s.identityRegistry.contains(newWallet),
            ErrorsLib.RecoveryNotPossible()
        );

        _transfer(lostWallet, newWallet, investorTokens);

        uint256 frozenTokens = s.frozenStatus[lostWallet].amount;
        if (frozenTokens > 0) {
            s.frozenStatus[lostWallet].amount = 0;
            emit ERC3643EventsLib.TokensUnfrozen(lostWallet, frozenTokens);
            s.frozenStatus[newWallet].amount += frozenTokens;
            emit ERC3643EventsLib.TokensFrozen(newWallet, frozenTokens);
        }

        if (s.frozenStatus[lostWallet].addressFrozen) {
            s.frozenStatus[lostWallet].addressFrozen = false;
            emit ERC3643EventsLib.AddressFrozen(lostWallet, false, address(this));

            if (!s.frozenStatus[newWallet].addressFrozen) {
                s.frozenStatus[newWallet].addressFrozen = true;
                emit ERC3643EventsLib.AddressFrozen(newWallet, true, address(this));
            }
        }
        IIdentityRegistry registry = IIdentityRegistry(address(s.identityRegistry));
        if (!registry.isLocallyRegistered(newWallet)) {
            s.identityRegistry
                .registerIdentity(
                    newWallet, IIdentity(investorOnchainId), s.identityRegistry.investorCountry(lostWallet)
                );
        }
        if (registry.isLocallyRegistered(lostWallet)) {
            s.identityRegistry.deleteIdentity(lostWallet);
        }

        emit ERC3643EventsLib.RecoverySuccess(lostWallet, newWallet, investorOnchainId);

        return true;
    }

    /* ----- Transfer Functions ----- */

    /// @inheritdoc IERC20
    /// @notice ERC-20 overridden function that include logic to check for trade validity.
    /// Require that the msg.sender and to addresses are not frozen.
    /// Require that the value should not exceed available balance .
    /// Require that the to address is a verified address
    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        TokenStorage storage s = _tokenStorage();
        address sender = _msgSender();

        require(!s.frozenStatus[sender].addressFrozen, ErrorsLib.FrozenWallet(sender));
        require(!s.frozenStatus[to].addressFrozen, ErrorsLib.FrozenWallet(to));

        uint256 balance = balanceOf(sender) - s.frozenStatus[sender].amount;
        require(amount <= balance, IERC20Errors.ERC20InsufficientBalance(sender, balance, amount));

        if (s.identityRegistry.isVerified(to) && s.compliance.canTransfer(sender, to, amount)) {
            _transfer(sender, to, amount);
            s.compliance.transferred(sender, to, amount);
            return true;
        }

        revert ErrorsLib.TransferNotPossible();
    }

    /// @inheritdoc IERC3643
    function forcedTransfer(address from, address to, uint256 amount) public override restricted returns (bool) {
        uint256 balance = balanceOf(from);
        require(amount <= balance, IERC20Errors.ERC20InsufficientBalance(from, balance, amount));

        TokenStorage storage s = _tokenStorage();
        uint256 freeBalance = balance - s.frozenStatus[from].amount;
        if (amount > freeBalance) {
            uint256 tokensToUnfreeze = amount - freeBalance;
            s.frozenStatus[from].amount -= tokensToUnfreeze;
            emit ERC3643EventsLib.TokensUnfrozen(from, tokensToUnfreeze);
        }

        if (s.identityRegistry.isVerified(to)) {
            _transfer(from, to, amount);
            s.compliance.transferred(from, to, amount);
            return true;
        }

        revert ErrorsLib.TransferNotPossible();
    }

    /// @inheritdoc IERC20
    /// @notice ERC-20 overridden function that include logic to check for trade validity.
    /// Require that the from and to addresses are not frozen.
    /// Require that the value should not exceed available balance .
    /// Require that the to address is a verified address
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        TokenStorage storage s = _tokenStorage();
        require(!s.frozenStatus[to].addressFrozen, ErrorsLib.FrozenWallet(to));
        require(!s.frozenStatus[from].addressFrozen, ErrorsLib.FrozenWallet(from));

        uint256 balance = balanceOf(from) - s.frozenStatus[from].amount;
        require(amount <= balance, IERC20Errors.ERC20InsufficientBalance(from, balance, amount));

        if (s.identityRegistry.isVerified(to) && s.compliance.canTransfer(from, to, amount)) {
            address sender = _msgSender();
            if (!s.defaultAllowances[sender] || s.defaultAllowanceOptOuts[from]) {
                _approve(from, sender, allowance(from, sender) - amount);
            }
            _transfer(from, to, amount);
            s.compliance.transferred(from, to, amount);
            return true;
        }

        revert ErrorsLib.TransferNotPossible();
    }

    /// @inheritdoc IERC3643
    function batchTransfer(address[] calldata tos, uint256[] calldata amounts) external override {
        for (uint256 i = 0; i < tos.length; i++) {
            transfer(tos[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchForcedTransfer(address[] calldata froms, address[] calldata tos, uint256[] calldata amounts)
        external
        override
    {
        for (uint256 i = 0; i < froms.length; i++) {
            forcedTransfer(froms[i], tos[i], amounts[i]);
        }
    }

    /* ----- Default Allowance Functions ----- */

    /// @inheritdoc IToken
    function setAllowanceForAll(address[] calldata targets, bool allow) external override restricted {
        uint256 targetsCount = targets.length;
        require(targetsCount <= 100, ErrorsLib.ArraySizeLimited(100));

        TokenStorage storage s = _tokenStorage();
        for (uint256 i = 0; i < targetsCount; i++) {
            require(s.defaultAllowances[targets[i]] != allow, ErrorsLib.DefaultAllowanceAlreadySet(targets[i], allow));
            s.defaultAllowances[targets[i]] = allow;
            emit EventsLib.DefaultAllowanceUpdated(targets[i], allow, _msgSender());
        }
    }

    /// @inheritdoc IToken
    function setDefaultAllowance(bool allow) external override {
        TokenStorage storage s = _tokenStorage();
        address sender = _msgSender();
        require(s.defaultAllowanceOptOuts[sender] == allow, ErrorsLib.DefaultAllowanceOptOutAlreadySet(sender, allow));

        s.defaultAllowanceOptOuts[sender] = !allow;
        emit EventsLib.DefaultAllowanceOptOutUpdated(sender, !allow);
    }

    /// @inheritdoc IERC20
    function allowance(address _owner, address _spender)
        public
        view
        override(ERC20Upgradeable, IERC20)
        returns (uint256)
    {
        TokenStorage storage s = _tokenStorage();
        if (s.defaultAllowances[_spender] && !s.defaultAllowanceOptOuts[_owner]) {
            return type(uint256).max;
        }

        return super.allowance(_owner, _spender);
    }

    /* ----- ERC2771 Context Functions ----- */

    /// @inheritdoc ERC2771ContextUpgradeable
    function trustedForwarder() public view virtual override returns (address) {
        return _tokenStorage().trustedForwarder;
    }

    /// @inheritdoc IToken
    function setTrustedForwarder(address newTrustedForwarder) external restricted {
        _tokenStorage().trustedForwarder = newTrustedForwarder;

        emit EventsLib.TrustedForwarderSet(newTrustedForwarder);
    }

    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return super._contextSuffixLength();
    }

    /* ----- Utility Functions ----- */

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IToken).interfaceId
            || interfaceId == type(IERC173).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC3643).interfaceId || interfaceId == type(IERC20Permit).interfaceId;
    }

    function _tokenStorage() private pure returns (TokenStorage storage $) {
        assembly {
            $.slot := TOKEN_STORAGE_LOCATION
        }
    }

    function _erc20Storage() private pure returns (ERC20Upgradeable.ERC20Storage storage $) {
        assembly {
            $.slot := ERC20_STORAGE_LOCATION
        }
    }

    function _eip712Storage() private pure returns (EIP712Upgradeable.EIP712Storage storage $) {
        assembly {
            $.slot := EIP712_STORAGE_LOCATION
        }
    }

    function _emitUpdatedTokenInformation() internal {
        emit ERC3643EventsLib.UpdatedTokenInformation(name(), symbol(), decimals(), VERSION, _tokenStorage().onchainId);
    }

}
