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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import { ErrorsLib } from "../libraries/ErrorsLib.sol";
import { TokenRolesLib } from "../token/access/TokenRolesLib.sol";

import { EventsLib } from "../libraries/EventsLib.sol";

/* ---- TODO ----

    Work in progress while transitioning to AccessManager

*/

contract AgentRole is Ownable, AccessManaged {

    modifier onlyAgent() {
        require(isAgent(msg.sender), ErrorsLib.CallerDoesNotHaveAgentRole());
        _;
    }

    constructor(address accessManager) Ownable(msg.sender) AccessManaged(accessManager) { }

    function addAgent(address _agent) public onlyOwner {
        require(_agent != address(0), ErrorsLib.ZeroAddress());

        IAccessManager accessManager = IAccessManager(authority());
        accessManager.grantRole(TokenRolesLib.AGENT_MINTER, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_BURNER, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_PARTIAL_FREEZER, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_ADDRESS_FREEZER, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_RECOVERY_ADDRESS, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_FORCED_TRANSFER, _agent, 0);
        accessManager.grantRole(TokenRolesLib.AGENT_PAUSER, _agent, 0);
    }

    function removeAgent(address _agent) public onlyOwner {
        require(_agent != address(0), ErrorsLib.ZeroAddress());

        IAccessManager accessManager = IAccessManager(authority());
        accessManager.revokeRole(TokenRolesLib.AGENT_MINTER, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_BURNER, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_PARTIAL_FREEZER, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_ADDRESS_FREEZER, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_RECOVERY_ADDRESS, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_FORCED_TRANSFER, _agent);
        accessManager.revokeRole(TokenRolesLib.AGENT_PAUSER, _agent);
    }

    function isAgent(address _agent) public view returns (bool) {
        return false;
    }

}
