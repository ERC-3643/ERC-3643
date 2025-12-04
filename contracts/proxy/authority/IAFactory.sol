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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ITREXFactory } from "../../factory/ITREXFactory.sol";
import { EventsLib } from "../../libraries/EventsLib.sol";
import { IIAFactory } from "./IIAFactory.sol";
import { ITREXImplementationAuthority } from "./ITREXImplementationAuthority.sol";
import { TREXImplementationAuthority } from "./TREXImplementationAuthority.sol";

contract IAFactory is IIAFactory, IERC165 {

    /// variables
    /// address of the trex factory
    address private _trexFactory;

    /// mapping allowing to know if an IA was deployed by the factory or not
    mapping(address => bool) private _deployedByFactory;

    /// Errors

    error OnlyReferenceIACanDeploy();

    /// functions

    constructor(address trexFactory) {
        _trexFactory = trexFactory;
    }

    /// @inheritdoc IIAFactory
    function deployIA(address _token, address accessManager) external override returns (address) {
        require(ITREXFactory(_trexFactory).getImplementationAuthority() == msg.sender, OnlyReferenceIACanDeploy());
        TREXImplementationAuthority _newIA = new TREXImplementationAuthority(
            false, ITREXImplementationAuthority(msg.sender).getTREXFactory(), address(this), accessManager
        );
        _newIA.fetchVersion(ITREXImplementationAuthority(msg.sender).getCurrentVersion());
        _newIA.useTREXVersion(ITREXImplementationAuthority(msg.sender).getCurrentVersion());

        // TODO WIP AccessManager
        // Ownable(_newIA).transferOwnership(Ownable(_token).owner());

        _deployedByFactory[address(_newIA)] = true;
        emit EventsLib.ImplementationAuthorityDeployed(address(_newIA));
        return address(_newIA);
    }

    /// @inheritdoc IIAFactory
    function deployedByFactory(address _ia) external view override returns (bool) {
        return _deployedByFactory[_ia];
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IIAFactory).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

}
