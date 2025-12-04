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
///     NOTICE
///
///     The T-REX software is licensed under a proprietary license or the GPL v.3.
///     If you choose to receive it under the GPL v.3 license, the following applies:
///     T-REX is a suite of smart contracts implementing the ERC-3643 standard and
///     developed by Tokeny to manage and transfer financial assets on EVM blockchains
///
///     Copyright (C) 2025, Tokeny sàrl.
///
///     This program is free software: you can redistribute it and/or modify
///     it under the terms of the GNU General Public License as published by
///     the Free Software Foundation, either version 3 of the License, or
///     (at your option) any later version.
///
///     This program is distributed in the hope that it will be useful,
///     but WITHOUT ANY WARRANTY; without even the implied warranty of
///     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
///     GNU General Public License for more details.
///
///     You should have received a copy of the GNU General Public License
///     along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.30;

import { AccessManaged, IAccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { IERC3643IdentityRegistry } from "../../ERC-3643/IERC3643IdentityRegistry.sol";
import { ITREXFactory } from "../../factory/ITREXFactory.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { EventsLib } from "../../libraries/EventsLib.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IToken } from "../../token/IToken.sol";
import { IProxy } from "../interface/IProxy.sol";
import { IIAFactory } from "./IIAFactory.sol";
import { ITREXImplementationAuthority } from "./ITREXImplementationAuthority.sol";

contract TREXImplementationAuthority is ITREXImplementationAuthority, AccessManaged, IERC165 {

    /// variables
    /// current version
    Version private _currentVersion;

    /// mapping to get contracts of each version
    mapping(bytes32 => TREXContracts) private _contracts;

    /// reference ImplementationAuthority used by the TREXFactory
    bool private _reference;

    /// address of TREXFactory contract
    address private _trexFactory;

    /// address of factory for TREXImplementationAuthority contracts
    address private _iaFactory;

    /// functions

    /// @dev Constructor of the ImplementationAuthority contract
    /// @param referenceStatus boolean value determining if the contract
    /// is the main IA or an auxiliary contract
    /// @param trexFactory the address of TREXFactory referencing the main IA
    /// if `referenceStatus` is true then `trexFactory` at deployment is set
    /// on zero address. In that scenario, call `setTREXFactory` post-deployment
    /// @param iaFactory the address for the factory of IA contracts
    /// emits `ImplementationAuthoritySet` event
    /// emits a `IAFactorySet` event
    constructor(bool referenceStatus, address trexFactory, address iaFactory, address accessManager)
        AccessManaged(accessManager)
    {
        _reference = referenceStatus;
        _trexFactory = trexFactory;
        _iaFactory = iaFactory;
        emit EventsLib.ImplementationAuthoritySetWithStatus(referenceStatus, trexFactory);
        emit EventsLib.IAFactorySet(iaFactory);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function setTREXFactory(address trexFactory) external override restricted {
        require(
            isReferenceContract() && ITREXFactory(trexFactory).getImplementationAuthority() == address(this),
            ErrorsLib.OnlyReferenceContractCanCall()
        );
        _trexFactory = trexFactory;
        emit EventsLib.TREXFactorySet(trexFactory);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function setIAFactory(address iaFactory) external override restricted {
        require(
            isReferenceContract() && ITREXFactory(_trexFactory).getImplementationAuthority() == address(this),
            ErrorsLib.OnlyReferenceContractCanCall()
        );
        _iaFactory = iaFactory;
        emit EventsLib.IAFactorySet(iaFactory);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function addAndUseTREXVersion(Version calldata _version, TREXContracts calldata _trex) external override {
        addTREXVersion(_version, _trex);
        useTREXVersion(_version);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function fetchVersion(Version calldata _version) external override {
        require(!isReferenceContract(), ErrorsLib.CannotCallOnReferenceContract());
        require(
            _contracts[_versionToBytes(_version)].tokenImplementation == address(0), ErrorsLib.VersionAlreadyFetched()
        );

        _contracts[_versionToBytes(_version)] =
            ITREXImplementationAuthority(getReferenceContract()).getContracts(_version);
        emit EventsLib.TREXVersionFetched(_version, _contracts[_versionToBytes(_version)]);
    }

    /// @inheritdoc ITREXImplementationAuthority
    // solhint-disable-next-line code-complexity, function-max-lines
    function changeImplementationAuthority(address _token, address _newImplementationAuthority) external override {
        require(_token != address(0), ErrorsLib.ZeroAddress());
        require(
            _newImplementationAuthority != address(0) || isReferenceContract(), ErrorsLib.OnlyReferenceContractCanCall()
        );

        address _ir = address(IToken(_token).identityRegistry());
        address _mc = address(IToken(_token).compliance());
        address _irs = address(IERC3643IdentityRegistry(_ir).identityStorage());
        address _ctr = address(IERC3643IdentityRegistry(_ir).topicsRegistry());
        address _tir = address(IERC3643IdentityRegistry(_ir).issuersRegistry());

        // calling this function requires ownership of ALL contracts of the T-REX suite
        require(
            _isAdmin(_token) && _isAdmin(_ir) && _isAdmin(_mc) && _isAdmin(_irs) && _isAdmin(_ctr) && _isAdmin(_tir),
            ErrorsLib.CallerNotOwnerOfAllImpactedContracts()
        );

        if (_newImplementationAuthority == address(0)) {
            _newImplementationAuthority = IIAFactory(_iaFactory).deployIA(_token, authority());
        } else {
            require(
                _versionToBytes(ITREXImplementationAuthority(_newImplementationAuthority).getCurrentVersion())
                    == _versionToBytes(_currentVersion),
                ErrorsLib.VersionOfNewIAMustBeTheSameAsCurrentIA()
            );
            require(
                !ITREXImplementationAuthority(_newImplementationAuthority).isReferenceContract()
                    || _newImplementationAuthority == getReferenceContract(),
                ErrorsLib.NewIAIsNotAReferenceContract()
            );
            require(
                IIAFactory(_iaFactory).deployedByFactory(_newImplementationAuthority)
                    || _newImplementationAuthority == getReferenceContract(),
                ErrorsLib.InvalidImplementationAuthority()
            );
        }

        IProxy(_token).setImplementationAuthority(_newImplementationAuthority);
        IProxy(_ir).setImplementationAuthority(_newImplementationAuthority);
        IProxy(_mc).setImplementationAuthority(_newImplementationAuthority);
        IProxy(_ctr).setImplementationAuthority(_newImplementationAuthority);
        IProxy(_tir).setImplementationAuthority(_newImplementationAuthority);
        // IRS can be shared by multiple tokens, and therefore could have been updated already
        if (IProxy(_irs).getImplementationAuthority() == address(this)) {
            IProxy(_irs).setImplementationAuthority(_newImplementationAuthority);
        }
        emit EventsLib.ImplementationAuthorityChanged(_token, _newImplementationAuthority);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getCurrentVersion() external view override returns (Version memory) {
        return _currentVersion;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getContracts(Version calldata _version) external view override returns (TREXContracts memory) {
        return _contracts[_versionToBytes(_version)];
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getTREXFactory() external view override returns (address) {
        return _trexFactory;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getTokenImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].tokenImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getCTRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].ctrImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getIRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].irImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getIRSImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].irsImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getTIRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].tirImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getMCImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].mcImplementation;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function addTREXVersion(Version calldata _version, TREXContracts calldata _trex) public override restricted {
        require(isReferenceContract(), ErrorsLib.OnlyReferenceContractCanCall());
        require(
            _contracts[_versionToBytes(_version)].tokenImplementation == address(0), ErrorsLib.VersionAlreadyExists()
        );

        require(
            _trex.ctrImplementation != address(0) && _trex.irImplementation != address(0)
                && _trex.irsImplementation != address(0) && _trex.mcImplementation != address(0)
                && _trex.tirImplementation != address(0) && _trex.tokenImplementation != address(0),
            ErrorsLib.ZeroAddress()
        );

        _contracts[_versionToBytes(_version)] = _trex;
        emit EventsLib.TREXVersionAdded(_version, _trex);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function useTREXVersion(Version calldata _version) public override restricted {
        require(_versionToBytes(_version) != _versionToBytes(_currentVersion), ErrorsLib.VersionAlreadyInUse());
        require(_contracts[_versionToBytes(_version)].tokenImplementation != address(0), ErrorsLib.NonExistingVersion());

        _currentVersion = _version;
        emit EventsLib.VersionUpdated(_version);
    }

    /// @inheritdoc ITREXImplementationAuthority
    function isReferenceContract() public view override returns (bool) {
        return _reference;
    }

    /// @inheritdoc ITREXImplementationAuthority
    function getReferenceContract() public view override returns (address) {
        return ITREXFactory(_trexFactory).getImplementationAuthority();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(ITREXImplementationAuthority).interfaceId || interfaceId == type(IERC173).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function _isAdmin(address contractAddress) private view returns (bool isAdmin) {
        (isAdmin,) = IAccessManager(IAccessManaged(contractAddress).authority()).hasRole(0, contractAddress);
    }

    /// @dev casting function Version => bytes to allow compare values easier
    function _versionToBytes(Version memory _version) private pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(_version.major, _version.minor, _version.patch)));
    }

}
