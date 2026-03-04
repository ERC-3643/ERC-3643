// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {AgentRole} from '../roles/AgentRole.sol';
import {IToken1155} from '../token/IToken1155.sol';
import {IClaimTopicsRegistry} from '../registry/interface/IClaimTopicsRegistry.sol';
import {IIdentityRegistry} from '../registry/interface/IIdentityRegistry.sol';
import {IModularCompliance} from '../compliance/modular/IModularCompliance.sol';
import {ITrustedIssuersRegistry} from '../registry/interface/ITrustedIssuersRegistry.sol';
import {IIdentityRegistryStorage} from '../registry/interface/IIdentityRegistryStorage.sol';
import {ITREXImplementationAuthority} from '../proxy/authority/ITREXImplementationAuthority.sol';
import {Token1155Proxy} from '../proxy/Token1155Proxy.sol';
import {ClaimTopicsRegistryProxy} from '../proxy/ClaimTopicsRegistryProxy.sol';
import {IdentityRegistryProxy} from '../proxy/IdentityRegistryProxy.sol';
import {IdentityRegistryStorageProxy} from '../proxy/IdentityRegistryStorageProxy.sol';
import {TrustedIssuersRegistryProxy} from '../proxy/TrustedIssuersRegistryProxy.sol';
import {ModularComplianceProxy} from '../proxy/ModularComplianceProxy.sol';
import {ITREXFactory} from './ITREXFactory.sol';
import '@onchain-id/solidity/contracts/factory/IIdFactory.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract TREX1155Factory is Ownable {
    error ZeroAddress();
    error TokenAlreadyDeployed(string salt);
    error ClaimPatternInvalid();
    error MaxClaimIssuersExceeded(uint256 count);
    error MaxClaimTopicsExceeded(uint256 count);
    error MaxAgentsExceeded(uint256 count);
    error NoTokenIdConfigs();

    address private _implementationAuthority;
    address private _idFactory;
    mapping(string => address) public tokenDeployed;

    event Deployed(address indexed _addr);
    event TREX1155SuiteDeployed(address indexed _token, address _ir, address _irs, address _tir, address _ctr, string indexed _salt);

    constructor(address implementationAuthority_, address idFactory_) {
        if (implementationAuthority_ == address(0)) revert ZeroAddress();
        if (idFactory_ == address(0)) revert ZeroAddress();
        _implementationAuthority = implementationAuthority_;
        _idFactory = idFactory_;
    }

    // solhint-disable-next-line code-complexity, function-max-lines
    function deployTREX1155Suite(
        string memory _salt,
        ITREXFactory.Token1155Details calldata _details,
        ITREXFactory.ClaimDetails calldata _claimDetails,
        ITREXFactory.TokenIdConfig[] calldata _tokenIdConfigs
    ) external onlyOwner {
        if (tokenDeployed[_salt] != address(0)) revert TokenAlreadyDeployed(_salt);
        if (_claimDetails.issuers.length != _claimDetails.issuerClaims.length) revert ClaimPatternInvalid();
        if (_claimDetails.issuers.length > 5) revert MaxClaimIssuersExceeded(_claimDetails.issuers.length);
        if (_claimDetails.claimTopics.length > 5) revert MaxClaimTopicsExceeded(_claimDetails.claimTopics.length);
        if (_details.irAgents.length > 5 || _details.tokenAgents.length > 5) {
            revert MaxAgentsExceeded(_details.irAgents.length > _details.tokenAgents.length ? _details.irAgents.length : _details.tokenAgents.length);
        }
        if (_tokenIdConfigs.length == 0) revert NoTokenIdConfigs();

        ITrustedIssuersRegistry tir = ITrustedIssuersRegistry(_deployTIR(_salt));
        IClaimTopicsRegistry ctr = IClaimTopicsRegistry(_deployCTR(_salt));
        IIdentityRegistryStorage irs;
        if (_details.irs == address(0)) {
            irs = IIdentityRegistryStorage(_deployIRS(_salt));
        } else {
            irs = IIdentityRegistryStorage(_details.irs);
        }
        IIdentityRegistry ir = IIdentityRegistry(_deployIR(_salt, address(tir), address(ctr), address(irs)));
        address tokenAddr = _deployToken1155(_salt, address(ir), _details.name, _details.symbol, _details.ONCHAINID);
        IToken1155 token1155 = IToken1155(tokenAddr);

        if (_details.ONCHAINID == address(0)) {
            address _tokenID = IIdFactory(_idFactory).createTokenIdentity(tokenAddr, _details.owner, _salt);
            token1155.setOnchainID(_tokenID);
        }
        for (uint256 i = 0; i < _claimDetails.claimTopics.length; i++) {
            ctr.addClaimTopic(_claimDetails.claimTopics[i]);
        }
        for (uint256 i = 0; i < _claimDetails.issuers.length; i++) {
            tir.addTrustedIssuer(IClaimIssuer(_claimDetails.issuers[i]), _claimDetails.issuerClaims[i]);
        }
        irs.bindIdentityRegistry(address(ir));
        AgentRole(address(ir)).addAgent(tokenAddr);
        for (uint256 i = 0; i < _details.irAgents.length; i++) {
            AgentRole(address(ir)).addAgent(_details.irAgents[i]);
        }
        for (uint256 i = 0; i < _details.tokenAgents.length; i++) {
            AgentRole(tokenAddr).addAgent(_details.tokenAgents[i]);
        }
        for (uint256 i = 0; i < _tokenIdConfigs.length; i++) {
            IModularCompliance mc = IModularCompliance(_deployMC(string(abi.encodePacked(_salt, '_mc', Strings.toString(i)))));
            for (uint256 j = 0; j < _tokenIdConfigs[i].complianceModules.length; j++) {
                if (!mc.isModuleBound(_tokenIdConfigs[i].complianceModules[j])) {
                    mc.addModule(_tokenIdConfigs[i].complianceModules[j]);
                }
                if (j < _tokenIdConfigs[i].complianceSettings.length) {
                    mc.callModuleFunction(_tokenIdConfigs[i].complianceSettings[j], _tokenIdConfigs[i].complianceModules[j]);
                }
            }
            token1155.createTokenId(_tokenIdConfigs[i].decimals, address(mc));
            (Ownable(address(mc))).transferOwnership(_details.owner);
        }
        tokenDeployed[_salt] = tokenAddr;
        (Ownable(tokenAddr)).transferOwnership(_details.owner);
        (Ownable(address(ir))).transferOwnership(_details.owner);
        (Ownable(address(tir))).transferOwnership(_details.owner);
        (Ownable(address(ctr))).transferOwnership(_details.owner);
        emit TREX1155SuiteDeployed(tokenAddr, address(ir), address(irs), address(tir), address(ctr), _salt);
    }

    function getImplementationAuthority() external view returns (address) {
        return _implementationAuthority;
    }

    function getIdFactory() external view returns (address) {
        return _idFactory;
    }

    function getToken(string calldata _salt) external view returns (address) {
        return tokenDeployed[_salt];
    }

    function _deploy(string memory salt, bytes memory bytecode) private returns (address) {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode)
            let encoded_size := mload(bytecode)
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
        return addr;
    }

    function _deployTIR(string memory _salt) private returns (address) {
        bytes memory _code = type(TrustedIssuersRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }

    function _deployCTR(string memory _salt) private returns (address) {
        bytes memory _code = type(ClaimTopicsRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }

    function _deployMC(string memory _salt) private returns (address) {
        bytes memory _code = type(ModularComplianceProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }

    function _deployIRS(string memory _salt) private returns (address) {
        bytes memory _code = type(IdentityRegistryStorageProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }

    function _deployIR(
        string memory _salt,
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) private returns (address) {
        bytes memory _code = type(IdentityRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority, _trustedIssuersRegistry, _claimTopicsRegistry, _identityStorage);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }

    function _deployToken1155(
        string memory _salt,
        address _identityRegistry,
        string memory _name,
        string memory _symbol,
        address _onchainId
    ) private returns (address) {
        bytes memory _code = type(Token1155Proxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority, _identityRegistry, _name, _symbol, _onchainId);
        return _deploy(_salt, abi.encodePacked(_code, _constructData));
    }
}
