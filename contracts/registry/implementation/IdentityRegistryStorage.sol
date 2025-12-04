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

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ERC3643EventsLib } from "../../ERC-3643/ERC3643EventsLib.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IdentityRegistryStorageRolesLib } from "../access/IdentityRegistryStorageRolesLib.sol";
import { IERC3643IdentityRegistryStorage, IIdentityRegistryStorage } from "../interface/IIdentityRegistryStorage.sol";

contract IdentityRegistryStorage is IIdentityRegistryStorage, AccessManagedUpgradeable, IERC165 {

    /// @dev struct containing the identity contract and the country of the user
    struct Identity {
        IIdentity identityContract;
        uint16 investorCountry;
    }

    /// @custom:storage-location erc7201:ERC3643.storage.IdentityRegistryStorage
    struct Storage {
        /// @dev mapping between a user address and the corresponding identity
        mapping(address user => Identity) identities;

        /// @dev array of Identity Registries linked to this storage
        address[] identityRegistries;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.IdentityRegistryStorage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0x6d25db4721129739b3a7e96c2537b7170fb9cfd72348ce376c7a189a3ab3ba00;

    constructor() {
        _disableInitializers();
    }

    function init(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function addIdentityToStorage(address userAddress, IIdentity identity, uint16 country)
        external
        override
        restricted
    {
        require(userAddress != address(0) && address(identity) != address(0), ErrorsLib.ZeroAddress());

        Storage storage s = _getStorage();
        require(address(s.identities[userAddress].identityContract) == address(0), ErrorsLib.AddressAlreadyStored());
        s.identities[userAddress].identityContract = identity;
        s.identities[userAddress].investorCountry = country;
        emit ERC3643EventsLib.IdentityStored(userAddress, identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredIdentity(address userAddress, IIdentity identity) external override restricted {
        require(userAddress != address(0) && address(identity) != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(address(s.identities[userAddress].identityContract) != address(0), ErrorsLib.AddressNotYetStored());
        IIdentity oldIdentity = s.identities[userAddress].identityContract;
        s.identities[userAddress].identityContract = identity;
        emit ERC3643EventsLib.IdentityModified(oldIdentity, identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredInvestorCountry(address userAddress, uint16 country) external override restricted {
        require(userAddress != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(address(s.identities[userAddress].identityContract) != address(0), ErrorsLib.AddressNotYetStored());
        s.identities[userAddress].investorCountry = country;
        emit ERC3643EventsLib.CountryModified(userAddress, country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function removeIdentityFromStorage(address userAddress) external override restricted {
        require(userAddress != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(address(s.identities[userAddress].identityContract) != address(0), ErrorsLib.AddressNotYetStored());
        IIdentity oldIdentity = s.identities[userAddress].identityContract;
        delete s.identities[userAddress];
        emit ERC3643EventsLib.IdentityUnstored(userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function bindIdentityRegistry(address identityRegistry) external override restricted {
        require(identityRegistry != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(s.identityRegistries.length < 300, ErrorsLib.MaxIRByIRSReached(300));

        IAccessManager(authority()).grantRole(IdentityRegistryStorageRolesLib.AGENT, identityRegistry, 0);

        s.identityRegistries.push(identityRegistry);
        emit ERC3643EventsLib.IdentityRegistryBound(identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function unbindIdentityRegistry(address identityRegistry) external override restricted {
        require(identityRegistry != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(s.identityRegistries.length > 0, ErrorsLib.IdentityRegistryNotStored());
        uint256 length = s.identityRegistries.length;
        for (uint256 i = 0; i < length; i++) {
            if (s.identityRegistries[i] == identityRegistry) {
                s.identityRegistries[i] = s.identityRegistries[length - 1];
                s.identityRegistries.pop();
                break;
            }
        }

        IAccessManager(authority()).revokeRole(IdentityRegistryStorageRolesLib.AGENT, identityRegistry);

        emit ERC3643EventsLib.IdentityRegistryUnbound(identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function linkedIdentityRegistries() external view override returns (address[] memory) {
        return _getStorage().identityRegistries;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedIdentity(address userAddress) external view override returns (IIdentity) {
        return _getStorage().identities[userAddress].identityContract;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedInvestorCountry(address userAddress) external view override returns (uint16) {
        return _getStorage().identities[userAddress].investorCountry;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IERC3643IdentityRegistryStorage).interfaceId
            || interfaceId == type(IERC173).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
