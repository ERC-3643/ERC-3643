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

import "./ITREXGateway.sol";
import "../roles/AgentRole.sol";
import "../token/IToken.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// A required parameter was set to the Zero address.
error ZeroAddress();

/// The Public Deployment Status is already set properly
error PublicDeploymentAlreadyEnabled();

/// The Public Deployment Status is already set properly
error PublicDeploymentAlreadyDisabled();

/// The Deployment fees are already enabled
error DeploymentFeesAlreadyEnabled();

/// The Deployment fees are already disabled
error DeploymentFeesAlreadyDisabled();

/// The address is already a deployer
error DeployerAlreadyExists(address deployer);

/// The address is not a deployer
error DeployerDoesNotExist(address deployer);

/// Cannot deploy if not deployer when public deployment disabled
error PublicDeploymentsNotAllowed();

/// Public deployers can only deploy for themselves
error PublicCannotDeployOnBehalf();

/// Discount cannot be bigger than 10000 (100%)
error DiscountOutOfRange();

/// Only Owner or Agent can call
error OnlyAdminCall();

/// Batch Size is too big, could run out of gas
error BatchMaxLengthExceeded(uint16 lengthLimit);

/// The IRS is not registered on the Gateway, it cannot be reused in a deployment
error IRSNotRegistered(address irs);

/// The IRS is already registered on the Gateway
error IRSAlreadyRegistered(address irs);

/// The Factory is not the owner of the IRS, it cannot bind new Identity Registries to it
error IRSNotOwnedByFactory(address irs);

/// Only the registered owner of the IRS can call
error OnlyIRSOwnerCall(address irs);

/// The token owner is not allowed to reuse this IRS
error IRSUsageNotAuthorized(address irs, address tokenOwner);

/// The token owner is already allowed to reuse this IRS
error IRSUsageAlreadyAuthorized(address irs, address tokenOwner);


contract TREXGateway is ITREXGateway, AgentRole {

    /// address of the TREX Factory that is managed by the Gateway
    address private _factory;

    /// public deployment status variable
    bool private _publicDeploymentStatus;

    /// deployment fee details
    Fee private _deploymentFee;

    /// deployment fees enabling variable
    bool private _deploymentFeeEnabled;

    /// mapping containing all deployer addresses
    mapping(address => bool) private _deployers;

    /// mapping for deployment discounts on fees
    mapping(address => uint16) private _feeDiscount;

    /// mapping IRS address => registered owner of the IRS (controls reuse of the IRS in new deployments)
    mapping(address => address) private _irsOwner;

    /// mapping IRS address => token owner => allowed to reuse the IRS in new deployments
    mapping(address => mapping(address => bool)) private _irsAuthorizedUsers;

    /// constructor of the contract, setting up the factory address and
    /// the public deployment status
    constructor(address factory, bool publicDeploymentStatus) {
        _factory = factory;
        _publicDeploymentStatus = publicDeploymentStatus;
        emit FactorySet(factory);
        emit PublicDeploymentStatusSet(publicDeploymentStatus);
    }

    /**
     *  @dev See {ITREXGateway-setFactory}.
     */
    function setFactory(address factory) external override onlyOwner {
        if(factory == address(0)) {
            revert ZeroAddress();
        }
        _factory = factory;
        emit FactorySet(factory);
    }

    /**
     *  @dev See {ITREXGateway-setPublicDeploymentStatus}.
     */
    function setPublicDeploymentStatus(bool _isEnabled) external override onlyOwner {
        if(_isEnabled == _publicDeploymentStatus && _isEnabled == true) {
            revert PublicDeploymentAlreadyEnabled();
        }
        if(_isEnabled == _publicDeploymentStatus && _isEnabled == false) {
            revert PublicDeploymentAlreadyDisabled();
        }
        _publicDeploymentStatus = _isEnabled;
        emit PublicDeploymentStatusSet(_isEnabled);
    }

    /**
     *  @dev See {ITREXGateway-transferFactoryOwnership}.
     */
    function transferFactoryOwnership(address _newOwner) external override onlyOwner {
        Ownable(_factory).transferOwnership(_newOwner);
    }

    /**
     *  @dev See {ITREXGateway-enableDeploymentFee}.
     */
    function enableDeploymentFee(bool _isEnabled) external override onlyOwner {
        if(_isEnabled == _deploymentFeeEnabled && _isEnabled == true) {
            revert DeploymentFeesAlreadyEnabled();
        }
        if(_isEnabled == _deploymentFeeEnabled && _isEnabled == false) {
            revert DeploymentFeesAlreadyDisabled();
        }
        _deploymentFeeEnabled = _isEnabled;
        emit DeploymentFeeEnabled(_isEnabled);
    }

    /**
     *  @dev See {ITREXGateway-setDeploymentFee}.
     */
    function setDeploymentFee(uint256 _fee, address _feeToken, address _feeCollector) external override onlyOwner {
        if(_feeToken == address(0) || _feeCollector == address(0)) {
            revert ZeroAddress();
        }
        _deploymentFee.fee = _fee;
        _deploymentFee.feeToken = _feeToken;
        _deploymentFee.feeCollector = _feeCollector;
        emit DeploymentFeeSet(_fee, _feeToken, _feeCollector);
    }

    /**
     *  @dev See {ITREXGateway-batchAddDeployer}.
     */
    function batchAddDeployer(address[] calldata deployers) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(deployers.length > 500) {
            revert BatchMaxLengthExceeded(500);
        }
        for (uint256 i = 0; i < deployers.length; i++) {
            if(isDeployer(deployers[i])) {
                revert DeployerAlreadyExists(deployers[i]);
            }
            _deployers[deployers[i]] = true;
            emit DeployerAdded(deployers[i]);
        }
    }

    /**
     *  @dev See {ITREXGateway-addDeployer}.
     */
    function addDeployer(address deployer) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(isDeployer(deployer)) {
            revert DeployerAlreadyExists(deployer);
        }
        _deployers[deployer] = true;
        emit DeployerAdded(deployer);
    }

    /**
     *  @dev See {ITREXGateway-batchRemoveDeployer}.
     */
    function batchRemoveDeployer(address[] calldata deployers) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(deployers.length > 500) {
            revert BatchMaxLengthExceeded(500);
        }
        for (uint256 i = 0; i < deployers.length; i++) {
            if(!isDeployer(deployers[i])) {
                revert DeployerDoesNotExist(deployers[i]);
            }
            delete _deployers[deployers[i]];
            emit DeployerRemoved(deployers[i]);
        }
    }

    /**
     *  @dev See {ITREXGateway-removeDeployer}.
     */
    function removeDeployer(address deployer) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(!isDeployer(deployer)) {
            revert DeployerDoesNotExist(deployer);
        }
        delete _deployers[deployer];
        emit DeployerRemoved(deployer);
    }

    /**
     *  @dev See {ITREXGateway-batchApplyFeeDiscount}.
     */
    function batchApplyFeeDiscount(address[] calldata deployers, uint16[] calldata discounts) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(deployers.length > 500) {
            revert BatchMaxLengthExceeded(500);
        }
        for (uint256 i = 0; i < deployers.length; i++) {
            if(discounts[i] > 10000) {
                revert DiscountOutOfRange();
            }
            _feeDiscount[deployers[i]] = discounts[i];
            emit FeeDiscountApplied(deployers[i], discounts[i]);
        }
    }

    /**
     *  @dev See {ITREXGateway-applyFeeDiscount}.
     */
    function applyFeeDiscount(address deployer, uint16 discount) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(discount > 10000) {
            revert DiscountOutOfRange();
        }
        _feeDiscount[deployer] = discount;
        emit FeeDiscountApplied(deployer, discount);
    }

    /**
     *  @dev See {ITREXGateway-registerIRS}.
     */
    function registerIRS(address irs, address irsOwner) external override {
        if(!isAgent(msg.sender) && msg.sender != owner()) {
            revert OnlyAdminCall();
        }
        if(irs == address(0) || irsOwner == address(0)) {
            revert ZeroAddress();
        }
        if(_irsOwner[irs] != address(0)) {
            revert IRSAlreadyRegistered(irs);
        }
        if(Ownable(irs).owner() != _factory) {
            revert IRSNotOwnedByFactory(irs);
        }
        _irsOwner[irs] = irsOwner;
        emit IRSRegistered(irs, irsOwner);
    }

    /**
     *  @dev See {ITREXGateway-transferIRSOwnership}.
     */
    function transferIRSOwnership(address irs, address newOwner) external override {
        _onlyIRSOwner(irs);
        if(newOwner == address(0)) {
            revert ZeroAddress();
        }
        address previousOwner = _irsOwner[irs];
        _irsOwner[irs] = newOwner;
        emit IRSOwnershipTransferred(irs, previousOwner, newOwner);
    }

    /**
     *  @dev See {ITREXGateway-authorizeIRSUsage}.
     */
    function authorizeIRSUsage(address irs, address tokenOwner) external override {
        _onlyIRSOwner(irs);
        if(tokenOwner == address(0)) {
            revert ZeroAddress();
        }
        if(_irsAuthorizedUsers[irs][tokenOwner]) {
            revert IRSUsageAlreadyAuthorized(irs, tokenOwner);
        }
        _irsAuthorizedUsers[irs][tokenOwner] = true;
        emit IRSUsageAuthorized(irs, tokenOwner);
    }

    /**
     *  @dev See {ITREXGateway-revokeIRSUsage}.
     */
    function revokeIRSUsage(address irs, address tokenOwner) external override {
        _onlyIRSOwner(irs);
        if(!_irsAuthorizedUsers[irs][tokenOwner]) {
            revert IRSUsageNotAuthorized(irs, tokenOwner);
        }
        delete _irsAuthorizedUsers[irs][tokenOwner];
        emit IRSUsageRevoked(irs, tokenOwner);
    }

    /**
     *  @dev See {ITREXGateway-recoverIRSOwnership}.
     */
    function recoverIRSOwnership(address irs) external override {
        _onlyIRSOwner(irs);
        ITREXFactory(_factory).recoverContractOwnership(irs, msg.sender);
        emit IRSOwnershipRecovered(irs, msg.sender);
    }

    /**
     *  @dev See {ITREXGateway-batchDeployTREXSuite}.
     */
    function batchDeployTREXSuite(
        ITREXFactory.TokenDetails[] memory _tokenDetails,
        ITREXFactory.ClaimDetails[] memory _claimDetails) external override
    {
        if(_tokenDetails.length > 5) {
            revert BatchMaxLengthExceeded(5);
        }
        for (uint256 i = 0; i < _tokenDetails.length; i++) {
            deployTREXSuite(_tokenDetails[i], _claimDetails[i]);
        }
    }

    /**
     *  @dev See {ITREXGateway-getPublicDeploymentStatus}.
     */
    function getPublicDeploymentStatus() external override view returns(bool) {
        return _publicDeploymentStatus;
    }

    /**
     *  @dev See {ITREXGateway-getFactory}.
     */
    function getFactory() external override view returns(address) {
        return _factory;
    }

    /**
     *  @dev See {ITREXGateway-getDeploymentFee}.
     */
    function getDeploymentFee() external override view returns(Fee memory) {
        return _deploymentFee;
    }

    /**
     *  @dev See {ITREXGateway-isDeploymentFeeEnabled}.
     */
    function isDeploymentFeeEnabled() external override view returns(bool) {
        return _deploymentFeeEnabled;
    }

    /**
     *  @dev See {ITREXGateway-getIRSOwner}.
     */
    function getIRSOwner(address irs) external override view returns(address) {
        return _irsOwner[irs];
    }

    /**
     *  @dev See {ITREXGateway-deployTREXSuite}.
     */
    function deployTREXSuite(ITREXFactory.TokenDetails memory _tokenDetails, ITREXFactory.ClaimDetails memory _claimDetails)
    public override {
        if(_publicDeploymentStatus == false && !isDeployer(msg.sender)) {
            revert PublicDeploymentsNotAllowed();
        }
        if(_publicDeploymentStatus == true && msg.sender != _tokenDetails.owner && !isDeployer(msg.sender)) {
            revert PublicCannotDeployOnBehalf();
        }
        // an existing IRS can only be reused by its registered owner or by a token owner they authorized
        if(_tokenDetails.irs != address(0)) {
            _checkIRSUsage(_tokenDetails.irs, _tokenDetails.owner);
        }
        uint256 feeApplied = 0;
        if(_deploymentFeeEnabled == true) {
            if(_deploymentFee.fee > 0 && _feeDiscount[msg.sender] < 10000) {
                feeApplied = calculateFee(msg.sender);
                IERC20(_deploymentFee.feeToken).transferFrom(
                    msg.sender,
                    _deploymentFee.feeCollector,
                    feeApplied
                );
            }
        }
        string memory _salt  = string(abi.encodePacked(Strings.toHexString(_tokenDetails.owner), _tokenDetails.name));
        ITREXFactory(_factory).deployTREXSuite(_salt, _tokenDetails, _claimDetails);
        // a freshly deployed IRS is registered with the token owner as its owner
        if(_tokenDetails.irs == address(0)) {
            _registerDeployedIRS(_salt, _tokenDetails.owner);
        }
        emit GatewaySuiteDeploymentProcessed(msg.sender, _tokenDetails.owner, feeApplied);
    }

    /**
     *  @dev See {ITREXGateway-isDeployer}.
     */
    function isDeployer(address deployer) public override view returns(bool) {
        return _deployers[deployer];
    }

    /**
     *  @dev See {ITREXGateway-calculateFee}.
     */
    function calculateFee(address deployer) public override view returns(uint256) {
        return _deploymentFee.fee - ((_feeDiscount[deployer] * _deploymentFee.fee) / 10000);
    }

    /**
     *  @dev See {ITREXGateway-isIRSUsageAuthorized}.
     */
    function isIRSUsageAuthorized(address irs, address tokenOwner) public override view returns(bool) {
        return (_irsOwner[irs] != address(0)) && (_irsOwner[irs] == tokenOwner || _irsAuthorizedUsers[irs][tokenOwner]);
    }

    /// registers the IRS deployed by the factory for `_salt` with `irsOwner` as its owner
    function _registerDeployedIRS(string memory _salt, address irsOwner) private {
        address token = ITREXFactory(_factory).getToken(_salt);
        address irs = address(IToken(token).identityRegistry().identityStorage());
        _irsOwner[irs] = irsOwner;
        emit IRSRegistered(irs, irsOwner);
    }

    /// reverts if `tokenOwner` is not allowed to bind a new Identity Registry to `irs`
    /// or if the factory is not in a position to do the binding
    function _checkIRSUsage(address irs, address tokenOwner) private view {
        if(_irsOwner[irs] == address(0)) {
            revert IRSNotRegistered(irs);
        }
        if(!isIRSUsageAuthorized(irs, tokenOwner)) {
            revert IRSUsageNotAuthorized(irs, tokenOwner);
        }
        if(Ownable(irs).owner() != _factory) {
            revert IRSNotOwnedByFactory(irs);
        }
    }

    /// reverts if msg.sender is not the registered owner of the IRS
    function _onlyIRSOwner(address irs) private view {
        if(_irsOwner[irs] == address(0) || msg.sender != _irsOwner[irs]) {
            revert OnlyIRSOwnerCall(irs);
        }
    }
}
