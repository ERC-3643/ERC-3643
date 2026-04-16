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

import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
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
import { AgentRole } from "../../roles/AgentRole.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IClaimTopicsRegistry } from "../interface/IClaimTopicsRegistry.sol";
import { IIdentityRegistry } from "../interface/IIdentityRegistry.sol";
import { IIdentityRegistryStorage } from "../interface/IIdentityRegistryStorage.sol";
import { ITrustedIssuersRegistry } from "../interface/ITrustedIssuersRegistry.sol";

contract IdentityRegistry is IIdentityRegistry, OwnableUpgradeable, AccessManagedUpgradeable, AgentRole, IERC165 {

    /// @custom:storage-location erc7201:ERC3643.storage.IdentityRegistry
    struct Storage {
        IClaimTopicsRegistry tokenTopicsRegistry;
        ITrustedIssuersRegistry tokenIssuersRegistry;
        IIdentityRegistryStorage tokenIdentityStorage;
        bool checksDisabled;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.IdentityRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0x0ef1f877833723f95a1d6f26d44eb8729b1f7ecbea0628fd412c7dacaacfe800;

    // TODO: claim topic value to be specified
    uint256 public constant COUNTRY_CLAIM_TOPIC = 2_000_008;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param accessManagerAddress the address of the access manager
    /// @param trustedIssuersRegistryAddress the address of the trusted issuers registry
    /// @param claimTopicsRegistryAddress the address of the claim topics registry
    /// @param identityStorageAddress the address of the identity registry storage
    function init(
        address trustedIssuersRegistryAddress,
        address claimTopicsRegistryAddress,
        address identityStorageAddress,
        address accessManagerAddress
    ) external initializer {
        require(
            trustedIssuersRegistryAddress != address(0) && claimTopicsRegistryAddress != address(0)
                && identityStorageAddress != address(0),
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

        __Ownable_init(accessManagerAddress);
        __AccessManaged_init(accessManagerAddress);
    }

    /**
     *  @dev See {IIdentityRegistry-batchRegisterIdentity}.
     */
    function batchRegisterIdentity(
        address[] calldata userAddresses,
        IIdentity[] calldata identities,
        uint16[] calldata countries
    ) external override {
        for (uint256 i = 0; i < userAddresses.length; i++) {
            registerIdentity(userAddresses[i], identities[i], countries[i]);
        }
    }

    /**
     *  @dev See {IIdentityRegistry-updateIdentity}.
     */
    function updateIdentity(address userAddress, IIdentity userIdentity) external override restricted {
        IIdentity oldIdentity = identity(userAddress);
        _getStorage().tokenIdentityStorage.modifyStoredIdentity(userAddress, userIdentity);
        emit ERC3643EventsLib.IdentityUpdated(oldIdentity, userIdentity);
    }

    /**
     *  @dev See {IIdentityRegistry-updateCountry}.
     */
    function updateCountry(address, uint16) external override restricted {
        revert ErrorsLib.Deprecated();
    }

    /**
     *  @dev See {IIdentityRegistry-deleteIdentity}.
     */
    function deleteIdentity(address _userAddress) external override restricted {
        IIdentity oldIdentity = identity(_userAddress);
        _getStorage().tokenIdentityStorage.removeIdentityFromStorage(_userAddress);
        emit ERC3643EventsLib.IdentityRemoved(_userAddress, oldIdentity);
    }

    /**
     *  @dev See {IIdentityRegistry-setIdentityRegistryStorage}.
     */
    function setIdentityRegistryStorage(address _identityRegistryStorage) external override restricted {
        _getStorage().tokenIdentityStorage = IIdentityRegistryStorage(_identityRegistryStorage);
        emit ERC3643EventsLib.IdentityStorageSet(_identityRegistryStorage);
    }

    /**
     *  @dev See {IIdentityRegistry-setClaimTopicsRegistry}.
     */
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external override restricted {
        _getStorage().tokenTopicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        emit ERC3643EventsLib.ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }

    /**
     *  @dev See {IIdentityRegistry-setTrustedIssuersRegistry}.
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external override restricted {
        _getStorage().tokenIssuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        emit ERC3643EventsLib.TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    /**
     *  @dev See {IIdentityRegistry-disableEligibilityChecks}.
     */
    function disableEligibilityChecks() external override restricted {
        Storage storage s = _getStorage();
        require(!s.checksDisabled, ErrorsLib.EligibilityChecksDisabledAlready());
        s.checksDisabled = true;
        emit EventsLib.EligibilityChecksDisabled();
    }

    /**
     *  @dev See {IIdentityRegistry-enableEligibilityChecks}.
     */
    function enableEligibilityChecks() external override restricted {
        Storage storage s = _getStorage();
        require(s.checksDisabled, ErrorsLib.EligibilityChecksEnabledAlready());
        s.checksDisabled = false;
        emit EventsLib.EligibilityChecksEnabled();
    }

    /**
     *  @dev See {IIdentityRegistry-isVerified}.
     */
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

    /**
     *  @dev See {IIdentityRegistry-investorCountry}.
     *  Reads the country from a claim on the wallet's identity contract.
     */
    // TODO: no issuer validation — trusts whatever country claim is on the identity
    function investorCountry(address _userAddress) external view override returns (uint16) {
        IIdentity id = identity(_userAddress);
        if (address(id) == address(0)) return 0;

        bytes32[] memory claimIds = id.getClaimIdsByTopic(COUNTRY_CLAIM_TOPIC);
        if (claimIds.length == 0) return 0;

        (,,,, bytes memory data,) = id.getClaim(claimIds[0]);
        if (data.length == 0) return 0;

        return abi.decode(data, (uint16));
    }

    /**
     *  @dev See {IIdentityRegistry-issuersRegistry}.
     */
    function issuersRegistry() external view override returns (IERC3643TrustedIssuersRegistry) {
        return _getStorage().tokenIssuersRegistry;
    }

    /**
     *  @dev See {IIdentityRegistry-topicsRegistry}.
     */
    function topicsRegistry() external view override returns (IERC3643ClaimTopicsRegistry) {
        return _getStorage().tokenTopicsRegistry;
    }

    /**
     *  @dev See {IIdentityRegistry-identityStorage}.
     */
    function identityStorage() external view override returns (IERC3643IdentityRegistryStorage) {
        return _getStorage().tokenIdentityStorage;
    }

    /**
     *  @dev See {IIdentityRegistry-contains}.
     */
    function contains(address _userAddress) external view override returns (bool) {
        return address(identity(_userAddress)) != address(0);
    }

    /**
     *  @dev See {IIdentityRegistry-isLocallyRegistered}.
     */
    function isLocallyRegistered(address _userAddress) external view override returns (bool) {
        return _getStorage().tokenIdentityStorage.isLocallyStored(_userAddress);
    }

    /**
     *  @dev See {IIdentityRegistry-registerIdentity}.
     */
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) public override restricted {
        _getStorage().tokenIdentityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit ERC3643EventsLib.IdentityRegistered(_userAddress, _identity);
    }

    /**
     *  @dev See {IIdentityRegistry-identity}.
     */
    function identity(address _userAddress) public view override returns (IIdentity) {
        return _getStorage().tokenIdentityStorage.storedIdentity(_userAddress);
    }

    /**
     *  @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IIdentityRegistry).interfaceId
            || interfaceId == type(IERC3643IdentityRegistry).interfaceId || interfaceId == type(IERC173).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
