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

import "../compliance/modular/IModularCompliance.sol";
import "../errors/CommonErrors.sol";
import "../errors/InvalidArgumentErrors.sol";
import "../proxy/ClaimTopicsRegistryProxy.sol";
import "../proxy/IdentityRegistryProxy.sol";
import "../proxy/IdentityRegistryStorageProxy.sol";
import "../proxy/ModularComplianceProxy.sol";
import "../proxy/TokenProxy.sol";
import "../proxy/TrustedIssuersRegistryProxy.sol";
import "../proxy/authority/ITREXImplementationAuthority.sol";
import "../registry/interface/IClaimTopicsRegistry.sol";
import "../registry/interface/IIdentityRegistry.sol";
import "../registry/interface/IIdentityRegistryStorage.sol";
import "../registry/interface/ITrustedIssuersRegistry.sol";
import "../roles/AgentRole.sol";
import "../token/IToken.sol";
import "./ITREXFactory.sol";
import { ICreateX } from "@createx/ICreateX.sol";
import "@onchain-id/solidity/contracts/factory/IIdFactory.sol";

/// Errors

/// @dev Thrown when claim pattern is invalid.
error InvalidClaimPattern();

/// @dev Thrown when compliance pattern is invalid.
error InvalidCompliancePattern();

/// @dev Thrown when maximum number of claim issuers is reached.
/// @param _max max value.
error MaxClaimIssuersReached(uint256 _max);

/// @dev Thrown when maximum number of claim topicsis reached.
/// @param _max max value.
error MaxClaimTopicsReached(uint256 _max);

/// @dev Thrown when maximum number of agetns is reached.
/// @param _max max value.
error MaxAgentsReached(uint256 _max);

/// @dev Thrown when maximum number of module actions reached.
/// @param _max max value.
error MaxModuleActionsReached(uint256 _max);

/// @dev Thrown when token is already deployed.
error TokenAlreadyDeployed();

contract TREXFactory is ITREXFactory, Ownable {

    /// the address of the implementation authority contract used in the tokens deployed by the factory
    address private _implementationAuthority;

    /// the address of the Identity Factory used to deploy token OIDs
    address private _idFactory;

    address private immutable _create3Factory;

    /// mapping containing info about the token contracts corresponding to salt already used for CREATE3 deployments
    mapping(string => address) public tokenDeployed;

    /// constructor is setting the implementation authority and the Identity Factory of the TREX factory
    constructor(address implementationAuthority_, address idFactory_, address create3Factory_) Ownable(msg.sender) {
        setImplementationAuthority(implementationAuthority_);
        setIdFactory(idFactory_);

        require(create3Factory_ != address(0), ZeroAddress());
        _create3Factory = create3Factory_;
    }

    /**
     *  @dev See {ITREXFactory-deployTREXSuite}.
     */
    // solhint-disable-next-line code-complexity, function-max-lines
    function deployTREXSuite(
        string memory _salt,
        TokenDetails calldata _tokenDetails,
        ClaimDetails calldata _claimDetails
    ) external override onlyOwner {
        require(tokenDeployed[_salt] == address(0), TokenAlreadyDeployed());
        require((_claimDetails.issuers).length == (_claimDetails.issuerClaims).length, InvalidClaimPattern());
        require((_claimDetails.issuers).length <= 5, MaxClaimIssuersReached(5));
        require((_claimDetails.claimTopics).length <= 5, MaxClaimTopicsReached(5));
        require((_tokenDetails.irAgents).length <= 5 && (_tokenDetails.tokenAgents).length <= 5, MaxAgentsReached(5));
        require((_tokenDetails.complianceModules).length <= 30, MaxModuleActionsReached(30));
        require(
            (_tokenDetails.complianceModules).length >= (_tokenDetails.complianceSettings).length,
            InvalidCompliancePattern()
        );

        ITrustedIssuersRegistry tir = ITrustedIssuersRegistry(_deployTIR(_salt, _implementationAuthority));
        IClaimTopicsRegistry ctr = IClaimTopicsRegistry(_deployCTR(_salt, _implementationAuthority));
        IModularCompliance mc = IModularCompliance(_deployMC(_salt, _implementationAuthority));
        IIdentityRegistryStorage irs;
        if (_tokenDetails.irs == address(0)) {
            irs = IIdentityRegistryStorage(_deployIRS(_salt, _implementationAuthority));
        } else {
            irs = IIdentityRegistryStorage(_tokenDetails.irs);
        }
        IIdentityRegistry ir =
            IIdentityRegistry(_deployIR(_salt, _implementationAuthority, address(tir), address(ctr), address(irs)));
        IToken token = IToken(
            _deployToken(
                _salt,
                _implementationAuthority,
                address(ir),
                address(mc),
                _tokenDetails.name,
                _tokenDetails.symbol,
                _tokenDetails.decimals,
                _tokenDetails.ONCHAINID
            )
        );
        if (_tokenDetails.ONCHAINID == address(0)) {
            address _tokenID = IIdFactory(_idFactory).createTokenIdentity(address(token), _tokenDetails.owner, _salt);
            token.setOnchainID(_tokenID);
        }
        for (uint256 i = 0; i < (_claimDetails.claimTopics).length; i++) {
            ctr.addClaimTopic(_claimDetails.claimTopics[i]);
        }
        for (uint256 i = 0; i < (_claimDetails.issuers).length; i++) {
            tir.addTrustedIssuer(IClaimIssuer((_claimDetails).issuers[i]), _claimDetails.issuerClaims[i]);
        }
        irs.bindIdentityRegistry(address(ir));
        AgentRole(address(ir)).addAgent(address(token));
        for (uint256 i = 0; i < (_tokenDetails.irAgents).length; i++) {
            AgentRole(address(ir)).addAgent(_tokenDetails.irAgents[i]);
        }
        for (uint256 i = 0; i < (_tokenDetails.tokenAgents).length; i++) {
            AgentRole(address(token)).addAgent(_tokenDetails.tokenAgents[i]);
        }
        for (uint256 i = 0; i < (_tokenDetails.complianceModules).length; i++) {
            if (!mc.isModuleBound(_tokenDetails.complianceModules[i])) {
                mc.addModule(_tokenDetails.complianceModules[i]);
            }
            if (i < (_tokenDetails.complianceSettings).length) {
                mc.callModuleFunction(_tokenDetails.complianceSettings[i], _tokenDetails.complianceModules[i]);
            }
        }
        tokenDeployed[_salt] = address(token);
        (Ownable(address(token))).transferOwnership(_tokenDetails.owner);
        (Ownable(address(ir))).transferOwnership(_tokenDetails.owner);
        (Ownable(address(tir))).transferOwnership(_tokenDetails.owner);
        (Ownable(address(ctr))).transferOwnership(_tokenDetails.owner);
        (Ownable(address(mc))).transferOwnership(_tokenDetails.owner);
        emit TREXSuiteDeployed(
            address(token), address(ir), address(irs), address(tir), address(ctr), address(mc), _salt
        );
    }

    /**
     *  @dev See {ITREXFactory-recoverContractOwnership}.
     */
    function recoverContractOwnership(address _contract, address _newOwner) external override onlyOwner {
        (Ownable(_contract)).transferOwnership(_newOwner);
    }

    /**
     *  @dev See {ITREXFactory-getImplementationAuthority}.
     */
    function getImplementationAuthority() external view override returns (address) {
        return _implementationAuthority;
    }

    /**
     *  @dev See {ITREXFactory-getIdFactory}.
     */
    function getIdFactory() external view override returns (address) {
        return _idFactory;
    }

    /**
     *  @dev See {ITREXFactory-getCreate3Factory}.
     */
    function getCreate3Factory() external view override returns (address) {
        return _create3Factory;
    }

    /**
     *  @dev See {ITREXFactory-getToken}.
     */
    function getToken(string calldata _salt) external view override returns (address) {
        return tokenDeployed[_salt];
    }

    /**
     *  @dev See {ITREXFactory-setImplementationAuthority}.
     */
    function setImplementationAuthority(address implementationAuthority_) public override onlyOwner {
        require(implementationAuthority_ != address(0), ZeroAddress());
        // should not be possible to set an implementation authority that is not complete
        require(
            (ITREXImplementationAuthority(implementationAuthority_)).getTokenImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getCTRImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getIRImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getIRSImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getMCImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getTIRImplementation() != address(0),
            InvalidImplementationAuthority()
        );
        _implementationAuthority = implementationAuthority_;
        emit ImplementationAuthoritySet(implementationAuthority_);
    }

    /**
     *  @dev See {ITREXFactory-setIdFactory}.
     */
    function setIdFactory(address idFactory_) public override onlyOwner {
        require(idFactory_ != address(0), ZeroAddress());
        _idFactory = idFactory_;
        emit IdFactorySet(idFactory_);
    }

    /**
     * @dev Deploys a contract using CREATE3 and transfers ownership via postInit
     * @param salt Base salt for deployment
     * @param contractType Contract type identifier (e.g., "TIR", "CTR")
     * @param bytecode Full creation bytecode including constructor parameters
     */
    function _deploy(string memory salt, string memory contractType, bytes memory bytecode) internal returns (address) {
        // we need to add a contract type parameter to prevent the address collisions
        // because if we just depend on the salt it all the 6 contracts will have the same address so it will revert as we are deploying at same address 6 times
        // Salt layout (32 bytes)
        // 1) 20 bytes: factory address
        // 2) 1 byte: 0x00 (no chainid)
        // 3) 11 bytes: our normal salt
        bytes32 saltBytes = bytes32(
            abi.encodePacked(
                address(this), // only our address can hit the guarded branch
                bytes1(0x00), //  no chain binding since we will go with multichain addresses
                bytes11(keccak256(abi.encodePacked(salt, contractType))) // our normal salt
            )
        );

        // Prepare postInit call to transfer ownership from CREATE3 proxy to this contract
        bytes memory postInitData = abi.encodeWithSignature("postInit(address)", address(this));
        ICreateX.Values memory values = ICreateX.Values({ constructorAmount: 0, initCallAmount: 0 });

        address addr = ICreateX(_create3Factory).deployCreate3AndInit(saltBytes, bytecode, postInitData, values);
        emit Deployed(addr);
        return addr;
    }

    /// function used to deploy a trusted issuers registry using CREATE3
    function _deployTIR(string memory _salt, address implementationAuthority_) private returns (address) {
        bytes memory _code = type(TrustedIssuersRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "TIR", bytecode);
    }

    /// function used to deploy a claim topics registry using CREATE3
    function _deployCTR(string memory _salt, address implementationAuthority_) private returns (address) {
        bytes memory _code = type(ClaimTopicsRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "CTR", bytecode);
    }

    /// function used to deploy modular compliance contract using CREATE3
    function _deployMC(string memory _salt, address implementationAuthority_) private returns (address) {
        bytes memory _code = type(ModularComplianceProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "MC", bytecode);
    }

    /// function used to deploy an identity registry storage using CREATE3
    function _deployIRS(string memory _salt, address implementationAuthority_) private returns (address) {
        bytes memory _code = type(IdentityRegistryStorageProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "IRS", bytecode);
    }

    /// function used to deploy an identity registry using CREATE3
    function _deployIR(
        string memory _salt,
        address implementationAuthority_,
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) private returns (address) {
        bytes memory _code = type(IdentityRegistryProxy).creationCode;
        bytes memory _constructData =
            abi.encode(implementationAuthority_, _trustedIssuersRegistry, _claimTopicsRegistry, _identityStorage);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "IR", bytecode);
    }

    /// function used to deploy a token using CREATE3
    function _deployToken(
        string memory _salt,
        address implementationAuthority_,
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _onchainId
    ) private returns (address) {
        bytes memory _code = type(TokenProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority_, _identityRegistry, _compliance, _name, _symbol, _decimals, _onchainId
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, "Token", bytecode);
    }

}
