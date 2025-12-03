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

library ErrorsLib {

    // Common Errors
    error ZeroAddress();
    error ZeroValue();
    error ArraySizeLimited(uint256 _maxSize);
    error InitializationFailed();
    error InvalidImplementationAuthority();

    // Token Errors
    error AddressNotAgent(address _agent);
    error AgentNotAuthorized(address _agent, string _reason);
    error AlreadyInitialized();
    error AmountAboveFrozenTokens(uint256 _amount, uint256 _maxAmount);
    error ComplianceNotFollowed();
    error DefaultAllowanceOptOutAlreadySet(address user, bool optOut);
    error DefaultAllowanceAlreadySet(address spender, bool allowed);
    error DecimalsOutOfRange(uint256 _decimals);
    error EmptyString();
    error EnforcedPause();
    error ExpectedPause();
    error FrozenWallet(address user);
    error NoTokenToRecover();
    error RecoveryNotPossible();
    error TransferNotPossible();
    error UnverifiedIdentity();

    // ModularCompliance Errors
    error AddressNotATokenBoundToComplianceContract();
    error ComplianceNotSuitableForBindingToModule(address module);
    error MaxModulesReached(uint256 maxValue);
    error ModuleAlreadyBound();
    error ModuleNotBound();
    error OnlyOwnerOrTokenCanCall();
    error TokenNotBound();

    // Module Errors
    error ComplianceNotBound();
    error ComplianceAlreadyBound();
    error OnlyBoundComplianceCanCall();
    error OnlyComplianceContractCanCall();

    // TREXGateway Errors
    error SenderIsNotAdmin();
    error PublicDeploymentAlreadySet(bool _isEnabled);
    error DeploymentFeesAlreadySet(bool _isEnabled);
    error DeployerAlreadyExists(address deployer);
    error DeployerDoesNotExist(address deployer);
    error PublicDeploymentsNotAllowed();
    error PublicCannotDeployOnBehalf();
    error DiscountOutOfRange();
    error BatchMaxLengthExceeded(uint16 lengthLimit);

    // TREXFactory Errors
    error InvalidClaimPattern();
    error InvalidCompliancePattern();
    error MaxClaimIssuersReached(uint256 _max);
    error MaxClaimTopicsReached(uint256 _max);
    error MaxAgentsReached(uint256 _max);
    error MaxModuleActionsReached(uint256 _max);
    error TokenAlreadyDeployed();
    error ContractNotAccessManagerAdmin(address accessManager, address target);

    // Roles Errors
    error AccountAlreadyHasRole();
    error AccountDoesNotHaveRole();
    error CallerDoesNotHaveAgentRole();

    // ClaimTopicsRegistry Errors
    error ClaimTopicAlreadyExists();
    error MaxTopicsReached(uint256 _max);

    // IdentityRegistry Errors
    error EligibilityChecksDisabledAlready();
    error EligibilityChecksEnabledAlready();

    // IdentityRegistryStorage Errors
    error AddressAlreadyStored();
    error AddressNotYetStored();
    error IdentityRegistryNotStored();
    error MaxIRByIRSReached(uint256 _max);

    // TrustedIssuersRegistry Errors
    error ClaimTopicsCannotBeEmpty();
    error MaxClaimTopcisReached(uint256 _max);
    error MaxTrustedIssuersReached(uint256 _max);
    error NotATrustedIssuer();
    error TrustedClaimTopicsCannotBeEmpty();
    error TrustedIssuerAlreadyExists();
    error TrustedIssuerDoesNotExist();

    // TREXImplementationAuthority Errors
    error CallerNotOwnerOfAllImpactedContracts();
    error CannotCallOnReferenceContract();
    error NewIAIsNotAReferenceContract();
    error NonExistingVersion();
    error OnlyReferenceContractCanCall();
    error VersionAlreadyFetched();
    error VersionAlreadyExists();
    error VersionAlreadyInUse();
    error VersionOfNewIAMustBeTheSameAsCurrentIA();

    // AbstractProxy Errors
    error OnlyCurrentImplementationAuthorityCanCall();

}
