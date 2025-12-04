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
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ERC3643EventsLib } from "../../ERC-3643/ERC3643EventsLib.sol";
import { IERC3643TrustedIssuersRegistry } from "../../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { ITrustedIssuersRegistry } from "../interface/ITrustedIssuersRegistry.sol";

contract TrustedIssuersRegistry is ITrustedIssuersRegistry, AccessManagedUpgradeable, IERC165 {

    /// @custom:storage-location erc7201:ERC3643.storage.TrustedIssuersRegistry
    struct Storage {
        /// @dev Set containing all TrustedIssuers identity contract address.
        IClaimIssuer[] trustedIssuers;

        /// @dev Mapping between a trusted issuer address and its corresponding claimTopics.
        mapping(address issuer => uint256[]) trustedIssuerClaimTopics;

        /// @dev Mapping between a claim topic and the allowed trusted issuers for it.
        mapping(uint256 claimTopic => IClaimIssuer[]) claimTopicsToTrustedIssuers;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.TrustedIssuersRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0xcf1a470b7a594e056f36cedab0ef91f3f14bce049596c7dfdd4c7c9a318d5000;

    uint256 private constant MAX_CLAIM_TOPICS = 15;
    uint256 private constant MAX_TRUSTED_ISSUERS = 50;

    constructor() {
        _disableInitializers();
    }

    /// Functions

    function init(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics)
        external
        override
        restricted
    {
        require(address(_trustedIssuer) != address(0), ErrorsLib.ZeroAddress());

        Storage storage s = _getStorage();
        require(s.trustedIssuerClaimTopics[address(_trustedIssuer)].length == 0, ErrorsLib.TrustedIssuerAlreadyExists());
        require(_claimTopics.length > 0, ErrorsLib.TrustedClaimTopicsCannotBeEmpty());
        require(_claimTopics.length <= MAX_CLAIM_TOPICS, ErrorsLib.MaxClaimTopcisReached(MAX_CLAIM_TOPICS));
        require(s.trustedIssuers.length < MAX_TRUSTED_ISSUERS, ErrorsLib.MaxTrustedIssuersReached(MAX_TRUSTED_ISSUERS));

        s.trustedIssuers.push(_trustedIssuer);
        s.trustedIssuerClaimTopics[address(_trustedIssuer)] = _claimTopics;
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            s.claimTopicsToTrustedIssuers[_claimTopics[i]].push(_trustedIssuer);
        }
        emit ERC3643EventsLib.TrustedIssuerAdded(_trustedIssuer, _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function removeTrustedIssuer(IClaimIssuer trustedIssuer) external override restricted {
        require(address(trustedIssuer) != address(0), ErrorsLib.ZeroAddress());

        Storage storage s = _getStorage();
        require(s.trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, ErrorsLib.NotATrustedIssuer());

        uint256 length = s.trustedIssuers.length;
        for (uint256 i = 0; i < length; i++) {
            if (s.trustedIssuers[i] == trustedIssuer) {
                s.trustedIssuers[i] = s.trustedIssuers[length - 1];
                s.trustedIssuers.pop();
                break;
            }
        }

        // Remove claims from this issuer
        for (
            uint256 claimTopicIndex = 0;
            claimTopicIndex < s.trustedIssuerClaimTopics[address(trustedIssuer)].length;
            claimTopicIndex++
        ) {
            uint256 claimTopic = s.trustedIssuerClaimTopics[address(trustedIssuer)][claimTopicIndex];
            uint256 topicsLength = s.claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 i = 0; i < topicsLength; i++) {
                if (s.claimTopicsToTrustedIssuers[claimTopic][i] == trustedIssuer) {
                    s.claimTopicsToTrustedIssuers[claimTopic][i] =
                        s.claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    s.claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
            }
        }
        delete s.trustedIssuerClaimTopics[address(trustedIssuer)];
        emit ERC3643EventsLib.TrustedIssuerRemoved(trustedIssuer);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function updateIssuerClaimTopics(IClaimIssuer trustedIssuer, uint256[] calldata _claimTopics)
        external
        override
        restricted
    {
        require(address(trustedIssuer) != address(0), ErrorsLib.ZeroAddress());
        Storage storage s = _getStorage();
        require(s.trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, ErrorsLib.NotATrustedIssuer());
        require(_claimTopics.length <= MAX_CLAIM_TOPICS, ErrorsLib.MaxClaimTopcisReached(MAX_CLAIM_TOPICS));
        require(_claimTopics.length > 0, ErrorsLib.ClaimTopicsCannotBeEmpty());

        for (uint256 i = 0; i < s.trustedIssuerClaimTopics[address(trustedIssuer)].length; i++) {
            uint256 claimTopic = s.trustedIssuerClaimTopics[address(trustedIssuer)][i];
            uint256 topicsLength = s.claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 j = 0; j < topicsLength; j++) {
                if (s.claimTopicsToTrustedIssuers[claimTopic][j] == trustedIssuer) {
                    s.claimTopicsToTrustedIssuers[claimTopic][j] =
                        s.claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    s.claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
            }
        }
        s.trustedIssuerClaimTopics[address(trustedIssuer)] = _claimTopics;
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            s.claimTopicsToTrustedIssuers[_claimTopics[i]].push(trustedIssuer);
        }
        emit ERC3643EventsLib.ClaimTopicsUpdated(trustedIssuer, _claimTopics);
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuers() external view override returns (IClaimIssuer[] memory) {
        return _getStorage().trustedIssuers;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view override returns (IClaimIssuer[] memory) {
        return _getStorage().claimTopicsToTrustedIssuers[claimTopic];
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function isTrustedIssuer(address issuer) external view override returns (bool) {
        if (_getStorage().trustedIssuerClaimTopics[issuer].length > 0) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(IClaimIssuer trustedIssuer) external view override returns (uint256[] memory) {
        Storage storage s = _getStorage();
        require(s.trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, ErrorsLib.TrustedIssuerDoesNotExist());
        return s.trustedIssuerClaimTopics[address(trustedIssuer)];
    }

    /// @inheritdoc IERC3643TrustedIssuersRegistry
    function hasClaimTopic(address issuer, uint256 claimTopic) external view override returns (bool) {
        Storage storage s = _getStorage();
        uint256 length = s.trustedIssuerClaimTopics[issuer].length;
        uint256[] memory claimTopics = s.trustedIssuerClaimTopics[issuer];
        for (uint256 i = 0; i < length; i++) {
            if (claimTopics[i] == claimTopic) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IERC3643TrustedIssuersRegistry).interfaceId
            || interfaceId == type(IERC173).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
