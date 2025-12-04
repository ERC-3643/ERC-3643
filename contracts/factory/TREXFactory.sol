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

import { IIdFactory } from "@onchain-id/solidity/contracts/factory/IIdFactory.sol";
import { IClaimIssuer } from "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

import { IModularCompliance } from "../compliance/modular/IModularCompliance.sol";
import { ErrorsLib } from "../libraries/ErrorsLib.sol";
import { EventsLib } from "../libraries/EventsLib.sol";
import { ClaimTopicsRegistryProxy } from "../proxy/ClaimTopicsRegistryProxy.sol";
import { IdentityRegistryProxy } from "../proxy/IdentityRegistryProxy.sol";
import { IdentityRegistryStorageProxy } from "../proxy/IdentityRegistryStorageProxy.sol";
import { ModularComplianceProxy } from "../proxy/ModularComplianceProxy.sol";
import { TokenProxy } from "../proxy/TokenProxy.sol";
import { TrustedIssuersRegistryProxy } from "../proxy/TrustedIssuersRegistryProxy.sol";
import { ITREXImplementationAuthority } from "../proxy/authority/ITREXImplementationAuthority.sol";
import { IClaimTopicsRegistry } from "../registry/interface/IClaimTopicsRegistry.sol";
import { IIdentityRegistry } from "../registry/interface/IIdentityRegistry.sol";
import { IIdentityRegistryStorage } from "../registry/interface/IIdentityRegistryStorage.sol";
import { ITrustedIssuersRegistry } from "../registry/interface/ITrustedIssuersRegistry.sol";
import { IToken } from "../token/IToken.sol";
import { ITREXFactory } from "./ITREXFactory.sol";

contract TREXFactory is ITREXFactory, AccessManaged {

    /// the address of the implementation authority contract used in the tokens deployed by the factory
    address private _implementationAuthority;

    /// the address of the Identity Factory used to deploy token OIDs
    address private _idFactory;

    /// mapping containing info about the token contracts corresponding to salt already used for CREATE2 deployments
    mapping(string => address) public tokenDeployed;

    /// constructor is setting the implementation authority and the Identity Factory of the TREX factory
    constructor(address implementationAuthority_, address idFactory_, address accessManager)
        AccessManaged(accessManager)
    {
        setImplementationAuthority(implementationAuthority_);
        setIdFactory(idFactory_);
    }

    /**
     *  @dev See {ITREXFactory-deployTREXSuite}.
     */
    // solhint-disable-next-line code-complexity, function-max-lines
    function deployTREXSuite(
        string memory _salt,
        TokenDetails calldata _tokenDetails,
        ClaimDetails calldata _claimDetails
    ) external override restricted {
        require(tokenDeployed[_salt] == address(0), ErrorsLib.TokenAlreadyDeployed());

        require(_tokenDetails.accessManager != address(0), ErrorsLib.ZeroAddress());
        (bool isAdmin,) = IAccessManager(_tokenDetails.accessManager).hasRole(0, address(this));
        require(isAdmin, ErrorsLib.ContractNotAccessManagerAdmin(_tokenDetails.accessManager, address(this)));

        require((_claimDetails.issuers).length == (_claimDetails.issuerClaims).length, ErrorsLib.InvalidClaimPattern());
        require((_claimDetails.issuers).length <= 5, ErrorsLib.MaxClaimIssuersReached(5));
        require((_claimDetails.claimTopics).length <= 5, ErrorsLib.MaxClaimTopicsReached(5));
        require(
            (_tokenDetails.irAgents).length <= 5 && (_tokenDetails.tokenAgents).length <= 5,
            ErrorsLib.MaxAgentsReached(5)
        );
        require((_tokenDetails.complianceModules).length <= 30, ErrorsLib.MaxModuleActionsReached(30));
        require(
            (_tokenDetails.complianceModules).length >= (_tokenDetails.complianceSettings).length,
            ErrorsLib.InvalidCompliancePattern()
        );

        ITrustedIssuersRegistry tir =
            ITrustedIssuersRegistry(_deployTIR(_salt, _implementationAuthority, _tokenDetails.accessManager));
        IClaimTopicsRegistry ctr =
            IClaimTopicsRegistry(_deployCTR(_salt, _implementationAuthority, _tokenDetails.accessManager));
        IModularCompliance mc =
            IModularCompliance(_deployMC(_salt, _implementationAuthority, _tokenDetails.accessManager));

        IIdentityRegistryStorage irs;
        if (_tokenDetails.irs == address(0)) {
            irs = IIdentityRegistryStorage(_deployIRS(_salt, _implementationAuthority, _tokenDetails.accessManager));
        } else {
            irs = IIdentityRegistryStorage(_tokenDetails.irs);
        }
        IIdentityRegistry ir = IIdentityRegistry(
            _deployIR(
                _salt, _implementationAuthority, address(tir), address(ctr), address(irs), _tokenDetails.accessManager
            )
        );
        IToken token = IToken(
            _deployToken(
                _salt,
                _implementationAuthority,
                address(ir),
                address(mc),
                _tokenDetails.name,
                _tokenDetails.symbol,
                _tokenDetails.decimals,
                _tokenDetails.ONCHAINID,
                _tokenDetails.accessManager
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

        /* TODO WIP AccessManager
        AgentRole(address(ir)).addAgent(address(token));
        for (uint256 i = 0; i < (_tokenDetails.irAgents).length; i++) {
            AgentRole(address(ir)).addAgent(_tokenDetails.irAgents[i]);
        }
        for (uint256 i = 0; i < (_tokenDetails.tokenAgents).length; i++) {
            AgentRole(address(token)).addAgent(_tokenDetails.tokenAgents[i]);
        }
        */

        for (uint256 i = 0; i < (_tokenDetails.complianceModules).length; i++) {
            if (!mc.isModuleBound(_tokenDetails.complianceModules[i])) {
                mc.addModule(_tokenDetails.complianceModules[i]);
            }
            if (i < (_tokenDetails.complianceSettings).length) {
                mc.callModuleFunction(_tokenDetails.complianceSettings[i], _tokenDetails.complianceModules[i]);
            }
        }
        tokenDeployed[_salt] = address(token);

        // TODO WIP AccessManager
        //(Ownable(address(token))).transferOwnership(_tokenDetails.owner);
        //(Ownable(address(ir))).transferOwnership(_tokenDetails.owner);
        //(Ownable(address(tir))).transferOwnership(_tokenDetails.owner);
        //(Ownable(address(ctr))).transferOwnership(_tokenDetails.owner);
        //(Ownable(address(mc))).transferOwnership(_tokenDetails.owner);

        emit EventsLib.TREXSuiteDeployed(
            address(token), address(ir), address(irs), address(tir), address(ctr), address(mc), _salt
        );
    }

    /**
     *  @dev See {ITREXFactory-recoverContractOwnership}.
     */
    // TODO WIP AccessManager
    // Maybe kept and call AccessManager (in the case Factory is still contract Admin)
    //function recoverContractOwnership(address _contract, address _newOwner) external override restricted {
    //    (Ownable(_contract)).transferOwnership(_newOwner);
    //}

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
     *  @dev See {ITREXFactory-getToken}.
     */
    function getToken(string calldata _salt) external view override returns (address) {
        return tokenDeployed[_salt];
    }

    /**
     *  @dev See {ITREXFactory-setImplementationAuthority}.
     */
    function setImplementationAuthority(address implementationAuthority_) public override restricted {
        require(implementationAuthority_ != address(0), ErrorsLib.ZeroAddress());
        // should not be possible to set an implementation authority that is not complete
        require(
            (ITREXImplementationAuthority(implementationAuthority_)).getTokenImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getCTRImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getIRImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getIRSImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getMCImplementation() != address(0)
                && (ITREXImplementationAuthority(implementationAuthority_)).getTIRImplementation() != address(0),
            ErrorsLib.InvalidImplementationAuthority()
        );
        _implementationAuthority = implementationAuthority_;
        emit EventsLib.ImplementationAuthoritySet(implementationAuthority_);
    }

    /**
     *  @dev See {ITREXFactory-setIdFactory}.
     */
    function setIdFactory(address idFactory_) public override restricted {
        require(idFactory_ != address(0), ErrorsLib.ZeroAddress());
        _idFactory = idFactory_;
        emit EventsLib.IdFactorySet(idFactory_);
    }

    /// deploy function with create2 opcode call
    /// returns the address of the contract created
    function _deploy(string memory salt, bytes memory bytecode) private returns (address) {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode) // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit EventsLib.Deployed(addr);
        return addr;
    }

    /// function used to deploy a trusted issuers registry using CREATE2
    function _deployTIR(string memory _salt, address implementationAuthority_, address accessManager)
        private
        returns (address)
    {
        bytes memory _code = type(TrustedIssuersRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_, accessManager);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy a claim topics registry using CREATE2
    function _deployCTR(string memory _salt, address implementationAuthority_, address accessManager)
        private
        returns (address)
    {
        bytes memory _code = type(ClaimTopicsRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_, accessManager);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy modular compliance contract using CREATE2
    function _deployMC(string memory _salt, address implementationAuthority_, address accessManager)
        private
        returns (address)
    {
        bytes memory _code = type(ModularComplianceProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_, accessManager);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy an identity registry storage using CREATE2
    function _deployIRS(string memory _salt, address implementationAuthority_, address accessManager)
        private
        returns (address)
    {
        bytes memory _code = type(IdentityRegistryStorageProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_, accessManager);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy an identity registry using CREATE2
    function _deployIR(
        string memory _salt,
        address implementationAuthority_,
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage,
        address _accessManager
    ) private returns (address) {
        bytes memory _code = type(IdentityRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority_, _trustedIssuersRegistry, _claimTopicsRegistry, _identityStorage, _accessManager
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy a token using CREATE2
    function _deployToken(
        string memory _salt,
        address implementationAuthority_,
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _onchainId,
        address _accessManager
    ) private returns (address) {
        bytes memory _code = type(TokenProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority_,
            _identityRegistry,
            _compliance,
            _name,
            _symbol,
            _decimals,
            _onchainId,
            _accessManager
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

}
