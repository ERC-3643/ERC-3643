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

import { ITREXImplementationAuthority } from "../proxy/authority/ITREXImplementationAuthority.sol";

library EventsLib {

    // ============================================
    // Common Events
    // ============================================

    event ImplementationAuthoritySet(address implementationAuthority);

    // ============================================
    // AgentRole / AgentRoleUpgradeable
    // ============================================

    event AgentAdded(address indexed agent);

    event AgentRemoved(address indexed agent);

    // ============================================
    // Token (IToken)
    // ============================================

    event AgentRestrictionsSet(
        address indexed agent,
        bool disableMint,
        bool disableBurn,
        bool disableAddressFreeze,
        bool disableForceTransfer,
        bool disablePartialFreeze,
        bool disablePause,
        bool disableRecovery
    );

    event DefaultAllowanceUpdated(address to, bool allowance, address updater);

    event DefaultAllowanceOptOutUpdated(address user, bool optOut);

    // ============================================
    // ModularCompliance
    // ============================================

    event ModuleInteraction(address indexed target, bytes4 selector);

    event ModuleAdded(address indexed module);

    event ModuleRemoved(address indexed module);

    // ============================================
    // AbstractModule / AbstractModuleUpgradeable
    // ============================================

    event ComplianceBound(address indexed compliance);

    event ComplianceUnbound(address indexed compliance);

    // ============================================
    // IdentityRegistry
    // ============================================

    event EligibilityChecksDisabled();

    event EligibilityChecksEnabled();

    // ============================================
    // TREXFactory
    // ============================================

    event Deployed(address indexed addr);

    event IdFactorySet(address idFactory);

    event TREXSuiteDeployed(
        address indexed token, address ir, address irs, address tir, address ctr, address mc, string indexed salt
    );

    // ============================================
    // TREXGateway
    // ============================================

    event FactorySet(address indexed factory);

    event PublicDeploymentStatusSet(bool indexed publicDeploymentStatus);

    event DeploymentFeeSet(uint256 indexed fee, address indexed feeToken, address indexed feeCollector);

    event DeploymentFeeEnabled(bool indexed isEnabled);

    event DeployerAdded(address indexed deployer);

    event DeployerRemoved(address indexed deployer);

    event FeeDiscountApplied(address indexed deployer, uint16 discount);

    event GatewaySuiteDeploymentProcessed(address indexed requester, address intendedOwner, uint256 feeApplied);

    // ============================================
    // TREXImplementationAuthority
    // ============================================

    event TREXVersionAdded(
        ITREXImplementationAuthority.Version indexed version, ITREXImplementationAuthority.TREXContracts indexed trex
    );

    event TREXVersionFetched(
        ITREXImplementationAuthority.Version indexed version, ITREXImplementationAuthority.TREXContracts indexed trex
    );

    event VersionUpdated(ITREXImplementationAuthority.Version indexed version);

    event ImplementationAuthoritySetWithStatus(bool referenceStatus, address trexFactory);

    event TREXFactorySet(address indexed trexFactory);

    event IAFactorySet(address indexed iaFactory);

    event ImplementationAuthorityChanged(address indexed token, address indexed newImplementationAuthority);

    // ============================================
    // IAFactory
    // ============================================

    event ImplementationAuthorityDeployed(address indexed ia);

}
