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

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ERC3643EventsLib } from "../../ERC-3643/ERC3643EventsLib.sol";
import { IERC3643ClaimTopicsRegistry } from "../../ERC-3643/IERC3643ClaimTopicsRegistry.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { IERC173 } from "../../roles/IERC173.sol";
import { IClaimTopicsRegistry } from "../interface/IClaimTopicsRegistry.sol";

contract ClaimTopicsRegistry is IClaimTopicsRegistry, AccessManagedUpgradeable, IERC165 {

    using EnumerableSet for EnumerableSet.UintSet;

    /// @custom:storage-location erc7201:ERC3643.storage.ClaimTopicsRegistry
    struct Storage {
        EnumerableSet.UintSet claimTopics;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.ClaimTopicsRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE_LOCATION = 0xeb77843660c963beb5d27db8816b70a285e2678d36793e5743f8650e153ee600;

    uint256 private constant MAX_CLAIM_TOPICS = 15;

    constructor() {
        _disableInitializers();
    }

    function init(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
    }

    /// @inheritdoc IERC3643ClaimTopicsRegistry
    function addClaimTopic(uint256 claimTopic) external override restricted {
        Storage storage s = _getStorage();
        require(s.claimTopics.length() < MAX_CLAIM_TOPICS, ErrorsLib.MaxTopicsReached(MAX_CLAIM_TOPICS));
        require(!s.claimTopics.contains(claimTopic), ErrorsLib.ClaimTopicAlreadyExists());

        s.claimTopics.add(claimTopic);
        emit ERC3643EventsLib.ClaimTopicAdded(claimTopic);
    }

    /// @inheritdoc IERC3643ClaimTopicsRegistry
    function removeClaimTopic(uint256 claimTopic) external override restricted {
        _getStorage().claimTopics.remove(claimTopic);
        emit ERC3643EventsLib.ClaimTopicRemoved(claimTopic);
    }

    /// @inheritdoc IERC3643ClaimTopicsRegistry
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _getStorage().claimTopics.values();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IERC3643ClaimTopicsRegistry).interfaceId || interfaceId == type(IERC173).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function _getStorage() internal pure returns (Storage storage s) {
        assembly {
            s.slot := STORAGE_LOCATION
        }
    }

}
