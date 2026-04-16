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

import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import { ModularCompliance } from "../compliance/modular/ModularCompliance.sol";
import { TREXFactory } from "../factory/TREXFactory.sol";
import { TREXGateway } from "../factory/TREXGateway.sol";
import { TREXImplementationAuthority } from "../proxy/authority/TREXImplementationAuthority.sol";
import { ClaimTopicsRegistry } from "../registry/implementation/ClaimTopicsRegistry.sol";
import { IdentityRegistry } from "../registry/implementation/IdentityRegistry.sol";
import { IdentityRegistryStorage } from "../registry/implementation/IdentityRegistryStorage.sol";
import { TrustedIssuersRegistry } from "../registry/implementation/TrustedIssuersRegistry.sol";
import { Token } from "../token/Token.sol";
import { RolesLib } from "./RolesLib.sol";

/// @title AccessManagerSetupLib
/// @notice Library for setting up roles and functions in AccessManager for the TREX suite contracts
library AccessManagerSetupLib {

    function setupTokenRoles(IAccessManager accessManager, address token) internal {
        // ------ TOKEN_ADMIN role ------
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = Token.setName.selector;
        functions[1] = Token.setSymbol.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.TOKEN_ADMIN);

        // ------ IDENTITY_ADMIN role ------
        functions = new bytes4[](3);
        functions[0] = Token.setOnchainID.selector;
        functions[1] = Token.setIdentityRegistry.selector;
        functions[2] = Token.setCompliance.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.IDENTITY_ADMIN);

        // ------ INFRA_ADMIN role ------
        functions = new bytes4[](1);
        functions[0] = Token.setTrustedForwarder.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.INFRA_ADMIN);

        // ------ SPENDING_ADMIN role ------
        functions = new bytes4[](1);
        functions[0] = Token.setAllowanceForAll.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.SPENDING_ADMIN);

        // ------ AGENT_MINTER role ------
        functions = new bytes4[](2);
        functions[0] = Token.mint.selector;
        functions[1] = Token.batchMint.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_MINTER);

        // ------ AGENT_BURNER role ------
        functions = new bytes4[](2);
        functions[0] = Token.burn.selector;
        functions[1] = Token.batchBurn.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_BURNER);

        // ------ AGENT_PARTIAL_FREEZER role ------
        functions = new bytes4[](4);
        functions[0] = Token.freezePartialTokens.selector;
        functions[1] = Token.batchFreezePartialTokens.selector;
        functions[2] = Token.unfreezePartialTokens.selector;
        functions[3] = Token.batchUnfreezePartialTokens.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_PARTIAL_FREEZER);

        // ------ AGENT_ADDRESS_FREEZER role ------
        functions = new bytes4[](2);
        functions[0] = Token.setAddressFrozen.selector;
        functions[1] = Token.batchSetAddressFrozen.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_ADDRESS_FREEZER);

        // ------ AGENT_RECOVERY_ADDRESS role ------
        functions = new bytes4[](1);
        functions[0] = Token.recoveryAddress.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_RECOVERY_ADDRESS);

        // ------ AGENT_FORCED_TRANSFER role ------
        functions = new bytes4[](2);
        functions[0] = Token.forcedTransfer.selector;
        functions[1] = Token.batchForcedTransfer.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_FORCED_TRANSFER);

        // ------ AGENT_PAUSER role ------
        functions = new bytes4[](2);
        functions[0] = Token.pause.selector;
        functions[1] = Token.unpause.selector;
        accessManager.setTargetFunctionRole(token, functions, RolesLib.AGENT_PAUSER);
    }

    function setupClaimTopicsRegistryRoles(IAccessManager accessManager, address claimTopicsRegistry) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = ClaimTopicsRegistry.addClaimTopic.selector;
        functions[1] = ClaimTopicsRegistry.removeClaimTopic.selector;
        accessManager.setTargetFunctionRole(claimTopicsRegistry, functions, RolesLib.OWNER);
    }

    function setupIdentityRegistryRoles(IAccessManager accessManager, address identityRegistry) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](5);
        functions[0] = IdentityRegistry.setIdentityRegistryStorage.selector;
        functions[1] = IdentityRegistry.setClaimTopicsRegistry.selector;
        functions[2] = IdentityRegistry.setTrustedIssuersRegistry.selector;
        functions[3] = IdentityRegistry.disableEligibilityChecks.selector;
        functions[4] = IdentityRegistry.enableEligibilityChecks.selector;
        accessManager.setTargetFunctionRole(identityRegistry, functions, RolesLib.OWNER);

        // ------ AGENT role ------
        functions = new bytes4[](3);
        functions[0] = IdentityRegistry.updateIdentity.selector;
        functions[1] = IdentityRegistry.deleteIdentity.selector;
        functions[2] = IdentityRegistry.registerIdentity.selector;
        accessManager.setTargetFunctionRole(identityRegistry, functions, RolesLib.AGENT);
    }

    function setupIdentityRegistryStorageRoles(IAccessManager accessManager, address identityRegistryStorage) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](3);
        functions[0] = IdentityRegistryStorage.bindIdentityRegistry.selector;
        functions[1] = IdentityRegistryStorage.unbindIdentityRegistry.selector;
        functions[2] = IdentityRegistryStorage.setIdFactory.selector;
        accessManager.setTargetFunctionRole(identityRegistryStorage, functions, RolesLib.OWNER);

        // ------ AGENT role ------
        functions = new bytes4[](3);
        functions[0] = IdentityRegistryStorage.addIdentityToStorage.selector;
        functions[1] = IdentityRegistryStorage.modifyStoredIdentity.selector;
        functions[2] = IdentityRegistryStorage.removeIdentityFromStorage.selector;
        accessManager.setTargetFunctionRole(identityRegistryStorage, functions, RolesLib.AGENT);
    }

    function setupTrustedIssuersRegistryRoles(IAccessManager accessManager, address trustedIssuersRegistry) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](3);
        functions[0] = TrustedIssuersRegistry.addTrustedIssuer.selector;
        functions[1] = TrustedIssuersRegistry.removeTrustedIssuer.selector;
        functions[2] = TrustedIssuersRegistry.updateIssuerClaimTopics.selector;
        accessManager.setTargetFunctionRole(trustedIssuersRegistry, functions, RolesLib.OWNER);
    }

    function setupModularComplianceRoles(IAccessManager accessManager, address modularCompliance) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](4);
        functions[0] = ModularCompliance.removeModule.selector;
        functions[1] = ModularCompliance.addAndSetModule.selector;
        functions[2] = ModularCompliance.addModule.selector;
        functions[3] = ModularCompliance.callModuleFunction.selector;
        accessManager.setTargetFunctionRole(modularCompliance, functions, RolesLib.OWNER);
    }

    function setupTREXGatewayRoles(IAccessManager accessManager, address trexGateway) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](10);
        functions[0] = TREXGateway.setFactory.selector;
        functions[1] = TREXGateway.setPublicDeploymentStatus.selector;
        functions[2] = TREXGateway.enableDeploymentFee.selector;
        functions[3] = TREXGateway.setDeploymentFee.selector;
        functions[4] = TREXGateway.batchAddDeployer.selector;
        functions[5] = TREXGateway.addDeployer.selector;
        functions[6] = TREXGateway.batchRemoveDeployer.selector;
        functions[7] = TREXGateway.removeDeployer.selector;
        functions[8] = TREXGateway.batchApplyFeeDiscount.selector;
        functions[9] = TREXGateway.applyFeeDiscount.selector;
        accessManager.setTargetFunctionRole(trexGateway, functions, RolesLib.OWNER);

        // ------ AGENT role ------
        functions = new bytes4[](6);
        functions[0] = TREXGateway.batchAddDeployer.selector;
        functions[1] = TREXGateway.addDeployer.selector;
        functions[2] = TREXGateway.batchRemoveDeployer.selector;
        functions[3] = TREXGateway.removeDeployer.selector;
        functions[4] = TREXGateway.batchApplyFeeDiscount.selector;
        functions[5] = TREXGateway.applyFeeDiscount.selector;
        accessManager.setTargetFunctionRole(trexGateway, functions, RolesLib.AGENT);
    }

    function setupTREXFactoryRoles(IAccessManager accessManager, address trexFactory) internal {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](3);
        functions[0] = TREXFactory.setImplementationAuthority.selector;
        functions[1] = TREXFactory.setIdFactory.selector;
        functions[2] = TREXFactory.deployTREXSuite.selector;
        accessManager.setTargetFunctionRole(trexFactory, functions, RolesLib.OWNER);
    }

    function setupTREXImplementationAuthorityRoles(IAccessManager accessManager, address trexImplementationAuthority)
        internal
    {
        // ------ OWNER role ------
        bytes4[] memory functions = new bytes4[](5);
        functions[0] = TREXImplementationAuthority.setTREXFactory.selector;
        functions[1] = TREXImplementationAuthority.setIAFactory.selector;
        functions[2] = TREXImplementationAuthority.addTREXVersion.selector;
        functions[3] = TREXImplementationAuthority.useTREXVersion.selector;
        functions[4] = TREXImplementationAuthority.addAndUseTREXVersion.selector;
        accessManager.setTargetFunctionRole(trexImplementationAuthority, functions, RolesLib.OWNER);
    }

    function setupLabels(IAccessManager accessManager) internal {
        accessManager.labelRole(RolesLib.OWNER, "TREX-Suite Owner");

        accessManager.labelRole(RolesLib.AGENT, "TREX-Suite Agent");
        accessManager.labelRole(RolesLib.AGENT_MINTER, "TREX-Suite Agent: Minter");
        accessManager.labelRole(RolesLib.AGENT_BURNER, "TREX-Suite Agent: Burner");
        accessManager.labelRole(RolesLib.AGENT_PARTIAL_FREEZER, "TREX-Suite Agent: Partial Freezer");
        accessManager.labelRole(RolesLib.AGENT_ADDRESS_FREEZER, "TREX-Suite Agent: Address Freezer");
        accessManager.labelRole(RolesLib.AGENT_RECOVERY_ADDRESS, "TREX-Suite Agent: Recovery Address");
        accessManager.labelRole(RolesLib.AGENT_FORCED_TRANSFER, "TREX-Suite Agent: Forced Transfer");
        accessManager.labelRole(RolesLib.AGENT_PAUSER, "TREX-Suite Agent: Pauser");

        accessManager.labelRole(RolesLib.TOKEN_ADMIN, "TREX-Suite Admin: Token");
        accessManager.labelRole(RolesLib.IDENTITY_ADMIN, "TREX-Suite Admin: Identity");
        accessManager.labelRole(RolesLib.INFRA_ADMIN, "TREX-Suite Admin: Infra");
        accessManager.labelRole(RolesLib.SPENDING_ADMIN, "TREX-Suite Admin: Spending");
    }

}
