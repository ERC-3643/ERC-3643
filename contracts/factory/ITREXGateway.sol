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
 *     Copyright (C) 2023, Tokeny sàrl.
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
pragma solidity 0.8.17;

import "./ITREXFactory.sol";

interface ITREXGateway {

    /// Types

    struct Fee {
        // amount of fee tokens to pay for 1 deployment
        uint256 fee;
        // address of the token used to pay fees
        address feeToken;
        // address collecting fees
        address feeCollector;
    }

    /// events

    /// event emitted when the _factory variable is set/modified
    event FactorySet(address indexed factory);

    /// event emitted when the public deployment status is set/modified
    event PublicDeploymentStatusSet(bool indexed publicDeploymentStatus);

    /// event emitted when the deployment fees details are set/modified
    event DeploymentFeeSet(uint256 indexed fee, address indexed feeToken, address indexed feeCollector);

    /// event emitted when the deployment fees are enabled/disabled
    event DeploymentFeeEnabled(bool indexed isEnabled);

    /// event emitted when an address is flagged as a deployer
    event DeployerAdded(address indexed deployer);

    /// event emitted when a deployer address loses deployment privileges
    event DeployerRemoved(address indexed deployer);

    /// event emitted when a discount on deployment fees is granted for an address
    event FeeDiscountApplied(address indexed deployer, uint16 discount);

    /// event emitted whenever a TREX token has been deployed by the TREX factory through the use of the Gateway
    event GatewaySuiteDeploymentProcessed(address indexed requester, address intendedOwner, uint256 feeApplied);

    /// event emitted when an Identity Registry Storage is registered on the Gateway with its owner
    /// (automatically at deployment of a new IRS, or manually by an admin for pre-existing IRS)
    event IRSRegistered(address indexed irs, address indexed irsOwner);

    /// event emitted when the registered owner of an IRS is changed
    event IRSOwnershipTransferred(address indexed irs, address indexed previousOwner, address indexed newOwner);

    /// event emitted when the owner of an IRS allows another token owner to bind new Identity Registries to it
    event IRSUsageAuthorized(address indexed irs, address indexed tokenOwner);

    /// event emitted when the owner of an IRS revokes the right of a token owner to bind new Identity Registries to it
    event IRSUsageRevoked(address indexed irs, address indexed tokenOwner);

    /// event emitted when the contract ownership of an IRS is recovered from the Factory by the registered IRS owner
    event IRSOwnershipRecovered(address indexed irs, address indexed newOwner);

    /// Functions

    /**
    * @notice Sets the factory contract address used for deploying TREX smart contracts.
    * @dev Only the owner can call this method. Emits a `FactorySet` event upon successful execution.
    * Reverts if the provided factory address is zero.
    * @param factory The address of the new factory contract.
    * emits FactorySet When the new factory address is set.
    */
    function setFactory(address factory) external;

    /**
    * @notice Sets the status for public deployments of TREX contracts.
    * @dev Enables or disables public deployments. If the function call doesn't change the current status, it will revert.
    * Only the owner can call this method. Emits a `PublicDeploymentStatusSet` event upon successful execution.
    * Reverts with `PublicDeploymentAlreadyEnabled` if trying to enable when already enabled.
    * Reverts with `PublicDeploymentAlreadyDisabled` if trying to disable when already disabled.
    * @param _isEnabled Determines if public deployments are enabled (`true`) or disabled (`false`).
    * emits PublicDeploymentStatusSet When the new public deployment status is set.
    */
    function setPublicDeploymentStatus(bool _isEnabled) external;

    /**
    * @notice Transfers the ownership of the Factory contract.
    * @dev Only the owner can call this method. Utilizes the `transferOwnership` function of the Ownable pattern.
    * @param _newOwner Address of the new owner for the Factory contract.
    */
    function transferFactoryOwnership(address _newOwner) external;

    /**
    * @notice Toggles the deployment fee status for TREX contracts.
    * @dev Enables or disables the deployment fees. If the function call doesn't change the current status, it will revert.
    * Only the owner can call this method. Emits a `DeploymentFeeEnabled` event upon successful execution.
    * Reverts with `DeploymentFeesAlreadyEnabled` if trying to enable when already enabled.
    * Reverts with `DeploymentFeesAlreadyDisabled` if trying to disable when already disabled.
    * @param _isEnabled Determines if deployment fees are enabled (`true`) or disabled (`false`).
    * emits DeploymentFeeEnabled When the new deployment fee status is set.
    */
    function enableDeploymentFee(bool _isEnabled) external;

    /**
    * @notice Sets the deployment fee details for TREX contracts.
    * @dev Only the owner can call this method. The function establishes the amount,
    * token type, and collector address for the deployment fee.
    * Reverts if either the provided `_feeToken` or `_feeCollector` address is zero.
    * Emits a `DeploymentFeeSet` event upon successful execution.
    * @param _fee The amount to be set as the deployment fee.
    * @param _feeToken Address of the token used for the deployment fee.
    * @param _feeCollector Address that will collect the deployment fees.
    * emits DeploymentFeeSet Indicates that the deployment fee details have been successfully set.
    */
    function setDeploymentFee(uint256 _fee, address _feeToken, address _feeCollector) external;

    /**
    * @notice Adds an address to the list of approved deployers.
    * @dev Only an admin (owner or agent) can call this method. If the provided `deployer` address
    * is already an approved deployer, the function will revert.
    * Emits a `DeployerAdded` event upon successful addition.
    * @param deployer Address to be added to the list of approved deployers.
    * emits DeployerAdded Indicates that a new deployer address has been successfully added.
    */
    function addDeployer(address deployer) external;

    /**
    * @notice Adds multiple addresses to the list of approved deployers in a single transaction.
    * @dev This function allows batch addition of deployers. It can only be called by an admin (owner or agent).
    * The function will revert if the length of the `deployers` array is more than 500 to prevent excessive gas consumption.
    * It will also revert if any address in the `deployers` array is already an approved deployer.
    * Emits a `DeployerAdded` event for each successfully added deployer.
    * @param deployers An array of addresses to be added to the list of approved deployers.
    */
    function batchAddDeployer(address[] calldata deployers) external;

    /**
    * @notice Removes an address from the list of approved deployers.
    * @dev Only an admin (owner or agent) can call this method. If the provided `deployer` address
    * is not an approved deployer, the function will revert.
    * Emits a `DeployerRemoved` event upon successful removal.
    * @param deployer Address to be removed from the list of approved deployers.
    * emits DeployerRemoved Indicates that a deployer address has been successfully removed.
    */
    function removeDeployer(address deployer) external;

    /**
    * @notice Removes multiple addresses from the list of approved deployers in a single transaction.
    * @dev This function allows batch removal of deployers. It can only be called by an admin (owner or agent).
    * The function will revert if the length of the `deployers` array is more than 500 to prevent excessive gas consumption.
    * It will also revert if any address in the `deployers` array is not an approved deployer.
    * Emits a `DeployerRemoved` event for each successfully removed deployer.
    * @param deployers An array of addresses to be removed from the list of approved deployers.
    */
    function batchRemoveDeployer(address[] calldata deployers) external;

    /**
    * @notice Applies a fee discount to a specific deployer's address.
    * @dev Only an admin (owner or agent) can call this method.
    * The fee discount is expressed per 10,000 (10000 = 100%, 1000 = 10%, etc.).
    * If the discount exceeds 10000, the function will revert. Emits a `FeeDiscountApplied` event upon successful application.
    * @param deployer Address of the deployer to which the discount will be applied.
    * @param discount The discount rate, expressed per 10,000.
    * emits FeeDiscountApplied Indicates that a fee discount has been successfully applied to a deployer.
    */
    function applyFeeDiscount(address deployer, uint16 discount) external;

    /**
    * @notice Applies fee discounts to multiple deployers in a single transaction.
    * @dev Allows batch application of fee discounts. Can only be called by an admin (owner or agent).
    * The function will revert if the length of the `deployers` array exceeds 500, to prevent excessive gas consumption.
    * Each discount in the `discounts` array is expressed per 10,000 (10000 = 100%, 1000 = 10%, etc.).
    * The function will also revert if any discount in the `discounts` array exceeds 10000.
    * Emits a `FeeDiscountApplied` event for each successfully applied discount.
    * @param deployers An array of deployer addresses to which the discounts will be applied.
    * @param discounts An array of discount rates, each corresponding
    * to a deployer in the `deployers` array, expressed per 10,000.
    */
    function batchApplyFeeDiscount(address[] calldata deployers, uint16[] calldata discounts) external;

    /**
    * @notice Deploys a TREX suite of contracts using provided token and claim details.
    * @dev This function performs multiple checks before deploying:
    * 1. If public deployments are disabled, only approved deployers can execute this function.
    * 2. If public deployments are enabled, an external entity can deploy only on its
    *    behalf and not for other addresses unless it's an approved deployer.
    *
    * If deployment fees are enabled and applicable (after considering any discounts for the deployer),
    * the fee is collected from the deployer's address.
    *
    * The actual TREX suite deployment is then triggered via the factory contract,
    * and a unique salt is derived from the token owner's address and the token name for the deployment.
    *
    * @param _tokenDetails Struct containing details necessary for token deployment such as name, symbol, etc.
    * @param _claimDetails Struct containing details related to claims for the token.
    * emits GatewaySuiteDeploymentProcessed This event is emitted post-deployment, indicating the deployer, the token
    * owner, and the fee applied.
    */
    function deployTREXSuite(
        ITREXFactory.TokenDetails memory _tokenDetails,
        ITREXFactory.ClaimDetails memory _claimDetails
    ) external;

    /**
    * @notice Deploys multiple TREX suites of contracts in a single transaction using provided arrays of token and claim details.
    * @dev This batch function allows deploying up to 5 TREX suites at once.
    * It performs the same checks as `deployTREXSuite` for each suite:
    * 1. If public deployments are disabled, only approved deployers can execute this function.
    * 2. If public deployments are enabled, an external entity can deploy only on its behalf
    * and not for other addresses unless it's an approved deployer.
    *
    * Deployment fees, if enabled and applicable, are collected for each suite deployment based on the deployer's address.
    *
    * Each TREX suite deployment is triggered via the factory contract, with a
    * unique salt derived from the token owner's address and token name.
    *
    * @param _tokenDetails Array of structs, each containing details necessary for token deployment such as name, symbol, etc.
    * @param _claimDetails Array of structs, each containing details related to claims for the respective token.
    * reverts with BatchMaxLengthExceeded if the length of either `_tokenDetails` or `_claimDetails` arrays exceeds 5.
    * reverts with PublicDeploymentsNotAllowed if public deployments are disabled and the caller is not an approved
    * deployer.
    * reverts with  PublicCannotDeployOnBehalf if public deployments are enabled and the caller attempts to deploy on
    * behalf of a different address without being an approved deployer.
    * emits GatewaySuiteDeploymentProcessed This event is emitted for each deployed suite, indicating
    * the deployer, the token owner, and any fee applied.
    */
    function batchDeployTREXSuite(
        ITREXFactory.TokenDetails[] memory _tokenDetails,
        ITREXFactory.ClaimDetails[] memory _claimDetails) external;

    /**
    * @notice Registers a pre-existing Identity Registry Storage on the Gateway and sets its owner.
    * @dev Only an admin (owner or agent of the Gateway) can call this method.
    * Used to onboard IRS contracts deployed before this version of the Gateway (or outside of it) so that
    * they can be reused in new deployments under the same access rules as IRS deployed through the Gateway.
    * The IRS must be owned by the Factory, otherwise the Factory cannot bind new Identity Registries to it.
    * Reverts with `IRSAlreadyRegistered` if the IRS is already registered.
    * Reverts with `IRSNotOwnedByFactory` if the Factory is not the owner of the IRS.
    * @param irs The address of the Identity Registry Storage.
    * @param irsOwner The address to register as owner of the IRS (typically the owner of the token(s) using it).
    * emits IRSRegistered
    */
    function registerIRS(address irs, address irsOwner) external;

    /**
    * @notice Transfers the registered ownership of an IRS on the Gateway to a new address.
    * @dev Only the registered owner of the IRS can call this method.
    * This does not change the on-chain `Ownable` owner of the IRS contract (which stays the Factory),
    * it only changes who controls the IRS sharing rules on the Gateway.
    * Reverts with `ZeroAddress` if `newOwner` is the zero address.
    * Reverts with `OnlyIRSOwnerCall` if the caller is not the registered owner of the IRS.
    * @param irs The address of the Identity Registry Storage.
    * @param newOwner The address of the new registered owner.
    * emits IRSOwnershipTransferred
    */
    function transferIRSOwnership(address irs, address newOwner) external;

    /**
    * @notice Allows another token owner to reuse the IRS in new TREX suite deployments.
    * @dev Only the registered owner of the IRS can call this method.
    * Once authorized, `tokenOwner` can be set as `TokenDetails.owner` in a deployment referencing this IRS,
    * which results in the new Identity Registry being bound to the IRS (and thus becoming an agent of it).
    * Reverts with `OnlyIRSOwnerCall` if the caller is not the registered owner of the IRS.
    * Reverts with `IRSUsageAlreadyAuthorized` if `tokenOwner` is already authorized.
    * @param irs The address of the Identity Registry Storage.
    * @param tokenOwner The address of the token owner allowed to reuse the IRS.
    * emits IRSUsageAuthorized
    */
    function authorizeIRSUsage(address irs, address tokenOwner) external;

    /**
    * @notice Revokes the right of a token owner to reuse the IRS in new TREX suite deployments.
    * @dev Only the registered owner of the IRS can call this method.
    * This only blocks future deployments; Identity Registries already bound to the IRS are not unbound
    * (the IRS owner can do that directly on the IRS after recovering its ownership).
    * Reverts with `OnlyIRSOwnerCall` if the caller is not the registered owner of the IRS.
    * Reverts with `IRSUsageNotAuthorized` if `tokenOwner` is not currently authorized.
    * @param irs The address of the Identity Registry Storage.
    * @param tokenOwner The address of the token owner losing the right to reuse the IRS.
    * emits IRSUsageRevoked
    */
    function revokeIRSUsage(address irs, address tokenOwner) external;

    /**
    * @notice Recovers the contract ownership of an IRS from the Factory.
    * @dev Only the registered owner of the IRS can call this method.
    * Calls `recoverContractOwnership` on the Factory, transferring the `Ownable` ownership of the IRS to the caller.
    * After this call the Factory can no longer bind new Identity Registries to this IRS, so any deployment
    * referencing it will revert with `IRSNotOwnedByFactory` until ownership is given back to the Factory.
    * Reverts with `OnlyIRSOwnerCall` if the caller is not the registered owner of the IRS.
    * @param irs The address of the Identity Registry Storage.
    * emits IRSOwnershipRecovered
    */
    function recoverIRSOwnership(address irs) external;

    /**
    * @notice Returns the registered owner of an IRS.
    * @param irs The address of the Identity Registry Storage.
    * @return The registered owner, or the zero address if the IRS is not registered on the Gateway.
    */
    function getIRSOwner(address irs) external view returns(address);

    /**
    * @notice Checks whether a token owner is allowed to reuse an IRS in new deployments.
    * @dev Returns true if `tokenOwner` is the registered owner of the IRS or has been authorized by them.
    * @param irs The address of the Identity Registry Storage.
    * @param tokenOwner The address of the token owner.
    * @return True if `tokenOwner` can reference `irs` in `TokenDetails.irs`, false otherwise.
    */
    function isIRSUsageAuthorized(address irs, address tokenOwner) external view returns(bool);

    /**
    * @notice Retrieves the current public deployment status.
    * @dev Indicates whether public deployments of TREX contracts are currently allowed.
    * @return A boolean value representing the public deployment status: `true` if
    * public deployments are allowed, `false` otherwise.
    */
    function getPublicDeploymentStatus() external view returns(bool);

    /**
    * @notice Retrieves the address of the current Factory contract.
    * @dev The Factory contract is responsible for deploying TREX contracts. This function allows querying its address.
    * @return Address of the current Factory contract.
    */
    function getFactory() external view returns(address);

    /**
    * @notice Retrieves the current deployment fee details.
    * @dev This function provides details about the deployment fee, including the amount, token type, and the collector address.
    * @return Fee struct containing:
    *   - `fee`: The amount to be paid as the deployment fee.
    *   - `feeToken`: Address of the token used for the deployment fee.
    *   - `feeCollector`: Address that collects the deployment fees.
    */
    function getDeploymentFee() external view returns(Fee memory);

    /**
    * @notice Checks if the deployment fee is currently enabled.
    * @dev Provides a way to determine if deployers are currently required to pay a fee when deploying TREX contracts.
    * @return A boolean value indicating whether the deployment fee is enabled (`true`) or disabled (`false`).
    */
    function isDeploymentFeeEnabled() external view returns(bool);

    /**
    * @notice Checks if the provided address is an approved deployer.
    * @dev Determines if a specific address has permissions to deploy TREX contracts.
    * @param deployer Address to be checked for deployer permissions.
    * @return A boolean value indicating whether the provided address is an approved deployer (`true`) or not (`false`).
    */
    function isDeployer(address deployer) external view returns(bool);

    /**
    * @notice Calculates the deployment fee for a given deployer after accounting for any discounts.
    * @dev The fee discount, if any, is expressed per 10,000 (e.g., 10000 = 100%, 1000 = 10%, etc.).
    * The final fee is derived by subtracting the discount amount from the original fee.
    * @param deployer Address of the deployer for which the fee will be calculated.
    * @return The calculated fee after accounting for potential discounts.
    */
    function calculateFee(address deployer) external view returns(uint256);
}
