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

pragma solidity 0.8.30;

import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ERC3643EventsLib } from "../../ERC-3643/ERC3643EventsLib.sol";
import { IERC3643ClaimTopicsRegistry } from "../../ERC-3643/IERC3643ClaimTopicsRegistry.sol";
import { IERC3643IdentityRegistry } from "../../ERC-3643/IERC3643IdentityRegistry.sol";
import { IERC3643IdentityRegistryStorage } from "../../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "../../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { EventsLib } from "../../libraries/EventsLib.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IClaimTopicsRegistry } from "../interface/IClaimTopicsRegistry.sol";
import { IIdentityRegistry } from "../interface/IIdentityRegistry.sol";
import { IIdentityRegistryStorage } from "../interface/IIdentityRegistryStorage.sol";
import { ITrustedIssuersRegistry } from "../interface/ITrustedIssuersRegistry.sol";

contract IdentityRegistry is IIdentityRegistry, AccessManagedUpgradeable, IERC165 {

    /// @custom:storage-location erc7201:ERC3643.storage.IdentityRegistry
    struct Storage {
        IClaimTopicsRegistry tokenTopicsRegistry;
        ITrustedIssuersRegistry tokenIssuersRegistry;
        IIdentityRegistryStorage tokenIdentityStorage;
        bool checksDisabled;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.IdentityRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0x0ef1f877833723f95a1d6f26d44eb8729b1f7ecbea0628fd412c7dacaacfe800;

    constructor() {
        _disableInitializers();
    }

    /// @param trustedIssuersRegistryAddress the trusted issuers registry linked to the Identity Registry
    /// @param claimTopicsRegistryAddress the claim topics registry linked to the Identity Registry
    /// @param identityStorageAddress the identity registry storage linked to the Identity Registry
    /// @param accessManager the access manager for access control
    /// @dev the constructor initiates the Identity Registry smart contract
    /// emits a `ClaimTopicsRegistrySet` event
    /// emits a `TrustedIssuersRegistrySet` event
    /// emits an `IdentityStorageSet` event
    function init(
        address trustedIssuersRegistryAddress,
        address claimTopicsRegistryAddress,
        address identityStorageAddress,
        address accessManager
    ) external initializer {
        require(
            trustedIssuersRegistryAddress != address(0) && claimTopicsRegistryAddress != address(0)
                && identityStorageAddress != address(0) && accessManager != address(0),
            ErrorsLib.ZeroAddress()
        );
        Storage storage s = _getStorage();
        s.tokenTopicsRegistry = IClaimTopicsRegistry(claimTopicsRegistryAddress);
        s.tokenIssuersRegistry = ITrustedIssuersRegistry(trustedIssuersRegistryAddress);
        s.tokenIdentityStorage = IIdentityRegistryStorage(identityStorageAddress);
        s.checksDisabled = false;

        emit ERC3643EventsLib.ClaimTopicsRegistrySet(claimTopicsRegistryAddress);
        emit ERC3643EventsLib.TrustedIssuersRegistrySet(trustedIssuersRegistryAddress);
        emit ERC3643EventsLib.IdentityStorageSet(identityStorageAddress);
        emit EventsLib.EligibilityChecksEnabled();

        __AccessManaged_init(accessManager);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function batchRegisterIdentity(
        address[] calldata userAddresses,
        IIdentity[] calldata identities,
        uint16[] calldata countries
    ) external override {
        for (uint256 i = 0; i < userAddresses.length; i++) {
            registerIdentity(userAddresses[i], identities[i], countries[i]);
        }
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function updateIdentity(address userAddress, IIdentity userIdentity) external override restricted {
        IIdentity oldIdentity = identity(userAddress);
        _getStorage().tokenIdentityStorage.modifyStoredIdentity(userAddress, userIdentity);
        emit ERC3643EventsLib.IdentityUpdated(oldIdentity, userIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function updateCountry(address userAddress, uint16 country) external override restricted {
        _getStorage().tokenIdentityStorage.modifyStoredInvestorCountry(userAddress, country);
        emit ERC3643EventsLib.CountryUpdated(userAddress, country);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function deleteIdentity(address userAddress) external override restricted {
        IIdentity oldIdentity = identity(userAddress);
        _getStorage().tokenIdentityStorage.removeIdentityFromStorage(userAddress);
        emit ERC3643EventsLib.IdentityRemoved(userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function setIdentityRegistryStorage(address identityRegistryStorage) external override restricted {
        _getStorage().tokenIdentityStorage = IIdentityRegistryStorage(identityRegistryStorage);
        emit ERC3643EventsLib.IdentityStorageSet(identityRegistryStorage);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function setClaimTopicsRegistry(address claimTopicsRegistry) external override restricted {
        _getStorage().tokenTopicsRegistry = IClaimTopicsRegistry(claimTopicsRegistry);
        emit ERC3643EventsLib.ClaimTopicsRegistrySet(claimTopicsRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function setTrustedIssuersRegistry(address trustedIssuersRegistry) external override restricted {
        _getStorage().tokenIssuersRegistry = ITrustedIssuersRegistry(trustedIssuersRegistry);
        emit ERC3643EventsLib.TrustedIssuersRegistrySet(trustedIssuersRegistry);
    }

    /// @inheritdoc IIdentityRegistry
    function disableEligibilityChecks() external override restricted {
        Storage storage s = _getStorage();
        require(!s.checksDisabled, ErrorsLib.EligibilityChecksDisabledAlready());
        s.checksDisabled = true;
        emit EventsLib.EligibilityChecksDisabled();
    }

    /// @inheritdoc IIdentityRegistry
    function enableEligibilityChecks() external override restricted {
        Storage storage s = _getStorage();
        require(s.checksDisabled, ErrorsLib.EligibilityChecksEnabledAlready());
        s.checksDisabled = false;
        emit EventsLib.EligibilityChecksEnabled();
    }

    /// @inheritdoc IERC3643IdentityRegistry
    // solhint-disable-next-line code-complexity
    function isVerified(address userAddress) external view override returns (bool) {
        Storage storage s = _getStorage();

        if (s.checksDisabled) return true;
        if (address(identity(userAddress)) == address(0)) return false;
        uint256[] memory requiredClaimTopics = s.tokenTopicsRegistry.getClaimTopics();
        if (requiredClaimTopics.length == 0) {
            return true;
        }

        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;
        uint256 claimTopic;
        for (claimTopic = 0; claimTopic < requiredClaimTopics.length; claimTopic++) {
            IClaimIssuer[] memory trustedIssuers =
                s.tokenIssuersRegistry.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic]);

            if (trustedIssuers.length == 0) return false;

            bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);
            for (uint256 i = 0; i < trustedIssuers.length; i++) {
                claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]));
            }

            for (uint256 j = 0; j < claimIds.length; j++) {
                (foundClaimTopic, scheme, issuer, sig, data,) = identity(userAddress).getClaim(claimIds[j]);

                if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
                    try IClaimIssuer(issuer)
                        .isClaimValid(identity(userAddress), requiredClaimTopics[claimTopic], sig, data) returns (
                        bool _validity
                    ) {
                        if (_validity) {
                            j = claimIds.length;
                        }
                        if (!_validity && j == (claimIds.length - 1)) {
                            return false;
                        }
                    } catch {
                        if (j == (claimIds.length - 1)) {
                            return false;
                        }
                    }
                } else if (j == (claimIds.length - 1)) {
                    return false;
                }
            }
        }
        return true;
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function investorCountry(address userAddress) external view override returns (uint16) {
        return _getStorage().tokenIdentityStorage.storedInvestorCountry(userAddress);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function issuersRegistry() external view override returns (IERC3643TrustedIssuersRegistry) {
        return _getStorage().tokenIssuersRegistry;
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function topicsRegistry() external view override returns (IERC3643ClaimTopicsRegistry) {
        return _getStorage().tokenTopicsRegistry;
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function identityStorage() external view override returns (IERC3643IdentityRegistryStorage) {
        return _getStorage().tokenIdentityStorage;
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function contains(address userAddress) external view override returns (bool) {
        return address(identity(userAddress)) != address(0);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function registerIdentity(address userAddress, IIdentity userIdentity, uint16 country) public override restricted {
        _getStorage().tokenIdentityStorage.addIdentityToStorage(userAddress, userIdentity, country);
        emit ERC3643EventsLib.IdentityRegistered(userAddress, userIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistry
    function identity(address userAddress) public view override returns (IIdentity) {
        return _getStorage().tokenIdentityStorage.storedIdentity(userAddress);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IIdentityRegistry).interfaceId
            || interfaceId == type(IERC3643IdentityRegistry).interfaceId || interfaceId == type(IERC173).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
