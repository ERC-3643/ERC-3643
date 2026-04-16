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

import { IIdFactory } from "@onchain-id/solidity/contracts/factory/IIdFactory.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ERC3643EventsLib } from "../../ERC-3643/ERC3643EventsLib.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { EventsLib } from "../../libraries/EventsLib.sol";
import { RolesLib } from "../../libraries/RolesLib.sol";
import { AgentRole } from "../../roles/AgentRole.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IERC3643IdentityRegistryStorage, IIdentityRegistryStorage } from "../interface/IIdentityRegistryStorage.sol";

contract IdentityRegistryStorage is
    IIdentityRegistryStorage,
    OwnableUpgradeable,
    AccessManagedUpgradeable,
    AgentRole,
    IERC165
{

    /// @dev struct containing the identity contract
    struct Identity {
        IIdentity identityContract;
    }

    /// @custom:storage-location erc7201:ERC3643.storage.IdentityRegistryStorage
    struct Storage {
        /// @dev mapping between a user address and the corresponding identity
        mapping(address user => Identity) identities;

        /// @dev array of Identity Registries linked to this storage
        address[] identityRegistries;

        /// @dev global identity registry used as a fallback when no local identity is stored
        IIdFactory idFactory;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.IdentityRegistryStorage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0x6d25db4721129739b3a7e96c2537b7170fb9cfd72348ce376c7a189a3ab3ba00;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param accessManagerAddress the address of the access manager
    /// @param idFactoryAddress the address of the global identity registry (IdFactory) used as fallback
    function init(address accessManagerAddress, address idFactoryAddress) external initializer {
        require(idFactoryAddress != address(0), ErrorsLib.ZeroAddress());
        __AccessManaged_init(accessManagerAddress);
        __Ownable_init(accessManagerAddress);
        _getStorage().idFactory = IIdFactory(idFactoryAddress);
        emit EventsLib.IdFactorySet(idFactoryAddress);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-addIdentityToStorage}.
     */
    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country)
        external
        override
        restricted
    {
        require(_userAddress != address(0) && address(_identity) != address(0), ErrorsLib.ZeroAddress());

        Storage storage s = _getStorage();
        require(address(s.identities[_userAddress].identityContract) == address(0), ErrorsLib.AddressAlreadyStored());
        s.identities[_userAddress].identityContract = _identity;
        emit ERC3643EventsLib.IdentityStored(_userAddress, _identity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-modifyStoredIdentity}.
     */
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external override restricted {
        require(_userAddress != address(0) && address(_identity) != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(address(s.identities[_userAddress].identityContract) != address(0), ErrorsLib.AddressNotYetStored());
        IIdentity oldIdentity = s.identities[_userAddress].identityContract;
        s.identities[_userAddress].identityContract = _identity;
        emit ERC3643EventsLib.IdentityModified(oldIdentity, _identity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-modifyStoredInvestorCountry}.
     */
    function modifyStoredInvestorCountry(address, uint16) external override restricted {
        revert ErrorsLib.Deprecated();
    }

    /**
     *  @dev See {IIdentityRegistryStorage-removeIdentityFromStorage}.
     */
    function removeIdentityFromStorage(address _userAddress) external override restricted {
        require(_userAddress != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(address(s.identities[_userAddress].identityContract) != address(0), ErrorsLib.AddressNotYetStored());
        IIdentity oldIdentity = s.identities[_userAddress].identityContract;
        delete s.identities[_userAddress];
        emit ERC3643EventsLib.IdentityUnstored(_userAddress, oldIdentity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-bindIdentityRegistry}.
     */
    function bindIdentityRegistry(address _identityRegistry) external override restricted {
        require(_identityRegistry != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(s.identityRegistries.length < 300, ErrorsLib.MaxIRByIRSReached(300));

        IAccessManager(authority()).grantRole(RolesLib.AGENT, _identityRegistry, 0);

        s.identityRegistries.push(_identityRegistry);
        emit ERC3643EventsLib.IdentityRegistryBound(_identityRegistry);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-unbindIdentityRegistry}.
     */
    function unbindIdentityRegistry(address _identityRegistry) external override restricted {
        require(_identityRegistry != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(s.identityRegistries.length > 0, ErrorsLib.IdentityRegistryNotStored());
        uint256 length = s.identityRegistries.length;
        for (uint256 i = 0; i < length; i++) {
            if (s.identityRegistries[i] == _identityRegistry) {
                s.identityRegistries[i] = s.identityRegistries[length - 1];
                s.identityRegistries.pop();
                break;
            }
        }

        IAccessManager(authority()).revokeRole(RolesLib.AGENT, _identityRegistry);

        emit ERC3643EventsLib.IdentityRegistryUnbound(_identityRegistry);
    }

    /**
     *  @notice Sets the global identity registry (IdFactory) used as a fallback when a wallet has no local identity.
     *  @param idFactoryAddress the address of the global identity registry
     */
    function setIdFactory(address idFactoryAddress) external restricted {
        require(idFactoryAddress != address(0), ErrorsLib.ZeroAddress());
        _getStorage().idFactory = IIdFactory(idFactoryAddress);
        emit EventsLib.IdFactorySet(idFactoryAddress);
    }

    /**
     *  @notice Returns the address of the global identity registry (IdFactory) used as a fallback.
     */
    function idFactory() external view returns (address) {
        return address(_getStorage().idFactory);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-linkedIdentityRegistries}.
     */
    function linkedIdentityRegistries() external view override returns (address[] memory) {
        return _getStorage().identityRegistries;
    }

    /**
     *  @dev See {IIdentityRegistryStorage-isLocallyStored}.
     */
    function isLocallyStored(address _userAddress) external view override returns (bool) {
        return address(_getStorage().identities[_userAddress].identityContract) != address(0);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-storedIdentity}.
     *  @dev Falls back to the global identity registry (IdFactory) when no local identity is stored.
     */
    function storedIdentity(address _userAddress) external view override returns (IIdentity) {
        Storage storage s = _getStorage();
        IIdentity local = s.identities[_userAddress].identityContract;
        if (address(local) != address(0)) {
            return local;
        }
        return IIdentity(s.idFactory.getIdentity(_userAddress));
    }

    /**
     *  @dev See {IIdentityRegistryStorage-storedInvestorCountry}.
     *  @dev Returns 0 for wallets that only exist in the global identity registry fallback, because the
     *  global registry does not track investor country.
     */
    function storedInvestorCountry(address) external pure override returns (uint16) {
        return 0;
    }

    /**
     *  @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IERC3643IdentityRegistryStorage).interfaceId
            || interfaceId == type(IERC173).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
