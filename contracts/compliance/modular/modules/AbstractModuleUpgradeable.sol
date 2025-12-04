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
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ErrorsLib } from "../../../libraries/ErrorsLib.sol";
import { EventsLib } from "../../../libraries/EventsLib.sol";
import { IERC173 } from "../../../roles/IERC173.sol";
import { IModule } from "./IModule.sol";

abstract contract AbstractModuleUpgradeable is
    IModule,
    Initializable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    MulticallUpgradeable,
    IERC165
{

    /// @custom:storage-location erc7201:ERC3643.storage.AbstractModule
    struct AbstractModuleStorage {
        /// compliance contract binding status
        mapping(address => bool) complianceBound;
        /// nonce for the module
        mapping(address => uint256) nonces;
    }

    // keccak256(abi.encode(uint256(keccak256("ERC3643.storage.AbstractModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _ABSTRACT_MODULE_STORAGE_LOCATION =
        0xf6cc97de1266c180cd39f3b311632644143ce7873d2927755382ad4b39e8ae00;

    /**
     * @dev Throws if `_compliance` is not a bound compliance contract address.
     */
    modifier onlyBoundCompliance(address _compliance) {
        require(_getAbstractModuleStorage().complianceBound[_compliance], ErrorsLib.ComplianceNotBound());
        _;
    }

    /**
     * @dev Throws if called from an address that is not a bound compliance contract.
     */
    modifier onlyComplianceCall() {
        require(_getAbstractModuleStorage().complianceBound[msg.sender], ErrorsLib.OnlyBoundComplianceCanCall());
        _;
    }

    /**
     * @dev prevents use of the implementation contracts
     */
    constructor() {
        _disableInitializers();
    }

    /**
     *  @dev See {IModule-bindCompliance}.
     */
    function bindCompliance(address _compliance) external override onlyProxy {
        require(_compliance != address(0), ErrorsLib.ZeroAddress());
        AbstractModuleStorage storage s = _getAbstractModuleStorage();
        require(!s.complianceBound[_compliance], ErrorsLib.ComplianceAlreadyBound());
        require(msg.sender == _compliance, ErrorsLib.OnlyComplianceContractCanCall());

        s.complianceBound[_compliance] = true;
        emit EventsLib.ComplianceBound(_compliance);
    }

    /**
     *  @dev See {IModule-unbindCompliance}.
     */
    function unbindCompliance(address _compliance) external override onlyComplianceCall onlyProxy {
        require(_compliance != address(0), ErrorsLib.ZeroAddress());
        require(msg.sender == _compliance, ErrorsLib.OnlyComplianceContractCanCall());

        AbstractModuleStorage storage s = _getAbstractModuleStorage();
        s.complianceBound[_compliance] = false;
        s.nonces[_compliance]++;

        emit EventsLib.ComplianceUnbound(_compliance);
    }

    /**
     *  @dev See {IModule-isComplianceBound}.
     */
    function isComplianceBound(address _compliance) external view override returns (bool) {
        return _getAbstractModuleStorage().complianceBound[_compliance];
    }

    function getNonce(address _compliance) public view returns (uint256) {
        return _getAbstractModuleStorage().nonces[_compliance];
    }

    /**
     *  @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId || interfaceId == type(IERC173).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function __AbstractModule_init(address accessManager) internal onlyInitializing {
        __AccessManaged_init(accessManager);
        __AbstractModule_init_unchained();
    }

    function __AbstractModule_init_unchained() internal onlyInitializing { }

    function _authorizeUpgrade(
        address /*newImplementation*/
    )
        internal
        virtual
        override
        restricted
    { }

    function _getAbstractModuleStorage() private pure returns (AbstractModuleStorage storage s) {
        assembly {
            s.slot := _ABSTRACT_MODULE_STORAGE_LOCATION
        }
    }

}
