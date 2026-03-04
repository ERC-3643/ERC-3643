/**
 * Deploy Token1155 Suite — Script explicativo
 *
 * Este script demonstra o deploy completo de um token ERC-1155 regulado (T-REX)
 * com 2 tokenIds, cada um com módulos de compliance diferentes:
 *
 *   tokenId 0 (18 decimais) → MaxBalanceModule  (máximo 10.000 tokens por carteira)
 *   tokenId 1 (8 decimais)  → TransferLimitModule (máximo 5.000 por transferência)
 *
 * Arquitetura do deploy:
 *
 *   ┌──────────────────────────────────────────────────────────┐
 *   │                  TREXImplementationAuthority              │
 *   │  (registra as implementações de todos os contratos)       │
 *   └────────────┬─────────────────────────────────────────────┘
 *                │
 *   ┌────────────▼────────────────────────────────────────┐
 *   │              Token1155Proxy                          │
 *   │  (proxy → Token1155 implementation)                  │
 *   │                                                      │
 *   │  tokenId 0 ──► ModularCompliance0                    │
 *   │                   └─► MaxBalanceModule (max: 10000)  │
 *   │                                                      │
 *   │  tokenId 1 ──► ModularCompliance1                    │
 *   │                   └─► TransferLimitModule (max: 5000)│
 *   └────────────┬────────────────────────────────────────┘
 *                │
 *   ┌────────────▼────────────────────────────────────────┐
 *   │        Registry Infrastructure                       │
 *   │  IdentityRegistry ◄── ClaimTopicsRegistry            │
 *   │        │               TrustedIssuersRegistry        │
 *   │        ▼                                             │
 *   │  IdentityRegistryStorage                             │
 *   └─────────────────────────────────────────────────────┘
 *
 * Para rodar:
 *   npx hardhat run scripts/deploy-token1155.ts
 *   npx hardhat run scripts/deploy-token1155.ts --network <rede>
 */

import { ethers } from 'hardhat';
import OnchainID from '@onchain-id/solidity';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deployer:', deployer.address);
  console.log('Balance:', ethers.utils.formatEther(await deployer.getBalance()), 'ETH\n');

  // =========================================================================
  // PASSO 1: Deploy das implementações (contratos lógicos, usados pelos proxies)
  // =========================================================================
  console.log('=== PASSO 1: Implementações ===');

  const claimTopicsRegistryImpl = await ethers.deployContract('ClaimTopicsRegistry', deployer);
  const trustedIssuersRegistryImpl = await ethers.deployContract('TrustedIssuersRegistry', deployer);
  const identityRegistryStorageImpl = await ethers.deployContract('IdentityRegistryStorage', deployer);
  const identityRegistryImpl = await ethers.deployContract('IdentityRegistry', deployer);
  const modularComplianceImpl = await ethers.deployContract('ModularCompliance', deployer);
  const tokenImpl = await ethers.deployContract('Token', deployer);
  const token1155Impl = await ethers.deployContract('Token1155', deployer);
  console.log('  Token1155 implementation:', token1155Impl.address);

  // =========================================================================
  // PASSO 2: TREXImplementationAuthority — Registra todas as implementações
  // =========================================================================
  console.log('\n=== PASSO 2: Implementation Authority ===');

  const trexIA = await ethers.deployContract(
    'TREXImplementationAuthority',
    [true, ethers.constants.AddressZero, ethers.constants.AddressZero],
    deployer,
  );

  // Registra a versão com TODAS as implementações (inclusive Token1155)
  await trexIA.addAndUseTREXVersion(
    { major: 4, minor: 0, patch: 0 },
    {
      tokenImplementation: tokenImpl.address,
      ctrImplementation: claimTopicsRegistryImpl.address,
      irImplementation: identityRegistryImpl.address,
      irsImplementation: identityRegistryStorageImpl.address,
      tirImplementation: trustedIssuersRegistryImpl.address,
      mcImplementation: modularComplianceImpl.address,
      token1155Implementation: token1155Impl.address,
    },
  );
  console.log('  TREXImplementationAuthority:', trexIA.address);

  // =========================================================================
  // PASSO 3: Deploy da infraestrutura de identidade (registries)
  // =========================================================================
  console.log('\n=== PASSO 3: Registry Infrastructure ===');

  const claimTopicsRegistry = await ethers
    .deployContract('ClaimTopicsRegistryProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('ClaimTopicsRegistry', proxy.address));
  console.log('  ClaimTopicsRegistry:', claimTopicsRegistry.address);

  const trustedIssuersRegistry = await ethers
    .deployContract('TrustedIssuersRegistryProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('TrustedIssuersRegistry', proxy.address));
  console.log('  TrustedIssuersRegistry:', trustedIssuersRegistry.address);

  const identityRegistryStorage = await ethers
    .deployContract('IdentityRegistryStorageProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('IdentityRegistryStorage', proxy.address));
  console.log('  IdentityRegistryStorage:', identityRegistryStorage.address);

  const identityRegistry = await ethers
    .deployContract(
      'IdentityRegistryProxy',
      [trexIA.address, trustedIssuersRegistry.address, claimTopicsRegistry.address, identityRegistryStorage.address],
      deployer,
    )
    .then((proxy) => ethers.getContractAt('IdentityRegistry', proxy.address));
  console.log('  IdentityRegistry:', identityRegistry.address);

  // Bind storage → registry
  await identityRegistryStorage.bindIdentityRegistry(identityRegistry.address);

  // =========================================================================
  // PASSO 4: Deploy dos módulos de compliance
  // =========================================================================
  console.log('\n=== PASSO 4: Compliance Modules ===');

  // Módulo 1: MaxBalanceModule — limita saldo máximo por carteira
  const maxBalanceModule = await ethers.deployContract('MaxBalanceModule', deployer);
  console.log('  MaxBalanceModule:', maxBalanceModule.address);

  // Módulo 2: TransferLimitModule — limita valor máximo por transferência
  const transferLimitModule = await ethers.deployContract('TransferLimitModule', deployer);
  console.log('  TransferLimitModule:', transferLimitModule.address);

  // =========================================================================
  // PASSO 5: Deploy das ModularCompliance (uma por tokenId)
  // =========================================================================
  console.log('\n=== PASSO 5: Modular Compliance (1 por tokenId) ===');

  // Compliance para tokenId 0: usa MaxBalanceModule
  const compliance0 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('ModularCompliance', proxy.address));
  console.log('  Compliance0 (tokenId 0):', compliance0.address);

  // Adiciona o MaxBalanceModule e configura max = 10.000
  await compliance0.addModule(maxBalanceModule.address);
  await compliance0.callModuleFunction(
    maxBalanceModule.interface.encodeFunctionData('setMaxBalance', [10000]),
    maxBalanceModule.address,
  );
  console.log('    └─ MaxBalanceModule adicionado (max: 10.000)');

  // Compliance para tokenId 1: usa TransferLimitModule
  const compliance1 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('ModularCompliance', proxy.address));
  console.log('  Compliance1 (tokenId 1):', compliance1.address);

  // Adiciona o TransferLimitModule e configura limit = 5.000
  await compliance1.addModule(transferLimitModule.address);
  await compliance1.callModuleFunction(
    transferLimitModule.interface.encodeFunctionData('setTransferLimit', [5000]),
    transferLimitModule.address,
  );
  console.log('    └─ TransferLimitModule adicionado (max: 5.000)');

  // =========================================================================
  // PASSO 6: Deploy do Token1155 via proxy
  // =========================================================================
  console.log('\n=== PASSO 6: Token1155 ===');

  // Deploy da OnchainID para o token (necessário para ERC-3643)
  const identityImplAuth = await new ethers.ContractFactory(
    OnchainID.contracts.ImplementationAuthority.abi,
    OnchainID.contracts.ImplementationAuthority.bytecode,
    deployer,
  ).deploy(
    (await new ethers.ContractFactory(
      OnchainID.contracts.Identity.abi,
      OnchainID.contracts.Identity.bytecode,
      deployer,
    ).deploy(deployer.address, true)).address,
  );

  const tokenOID = await new ethers.ContractFactory(
    OnchainID.contracts.IdentityProxy.abi,
    OnchainID.contracts.IdentityProxy.bytecode,
    deployer,
  ).deploy(identityImplAuth.address, deployer.address);

  const token1155 = await ethers
    .deployContract(
      'Token1155Proxy',
      [trexIA.address, identityRegistry.address, 'SecurityToken1155', 'ST1155', tokenOID.address],
      deployer,
    )
    .then((proxy) => ethers.getContractAt('Token1155', proxy.address));
  console.log('  Token1155:', token1155.address);
  console.log('  Name:', await token1155.name());
  console.log('  Symbol:', await token1155.symbol());

  // =========================================================================
  // PASSO 7: Criar tokenIds (cada um com sua compliance)
  // =========================================================================
  console.log('\n=== PASSO 7: Criar TokenIds ===');

  // tokenId 0: 18 decimais, compliance com MaxBalanceModule
  await token1155.createTokenId(18, compliance0.address);
  console.log('  tokenId 0: 18 decimais → MaxBalanceModule (max 10.000/carteira)');

  // tokenId 1: 8 decimais, compliance com TransferLimitModule
  await token1155.createTokenId(8, compliance1.address);
  console.log('  tokenId 1: 8 decimais  → TransferLimitModule (max 5.000/tx)');

  // Ambos começam pausados (padrão do createTokenId)
  console.log('  Status: ambos pausados (padrão)');
  console.log('  Total de tokenIds:', (await token1155.getTokenIdCount()).toString());

  // =========================================================================
  // PASSO 8: Configurar agents
  // =========================================================================
  console.log('\n=== PASSO 8: Agents ===');

  // O deployer se adiciona como agent (em produção, seria outra conta)
  await token1155.addAgent(deployer.address);
  await identityRegistry.addAgent(deployer.address);
  await identityRegistry.addAgent(token1155.address);
  console.log('  Agent adicionado:', deployer.address);

  // =========================================================================
  // RESUMO
  // =========================================================================
  console.log('\n══════════════════════════════════════════════════');
  console.log('  DEPLOY COMPLETO!');
  console.log('══════════════════════════════════════════════════');
  console.log('');
  console.log('  Token1155:              ', token1155.address);
  console.log('  IdentityRegistry:       ', identityRegistry.address);
  console.log('  IdentityRegistryStorage:', identityRegistryStorage.address);
  console.log('  ClaimTopicsRegistry:    ', claimTopicsRegistry.address);
  console.log('  TrustedIssuersRegistry: ', trustedIssuersRegistry.address);
  console.log('  Implementation Authority:', trexIA.address);
  console.log('');
  console.log('  tokenId 0 → Compliance: ', compliance0.address);
  console.log('               Module:     MaxBalanceModule (max: 10.000)');
  console.log('  tokenId 1 → Compliance: ', compliance1.address);
  console.log('               Module:     TransferLimitModule (max: 5.000)');
  console.log('');
  console.log('  Próximos passos:');
  console.log('    1. Registrar identidades dos investidores no IdentityRegistry');
  console.log('    2. Configurar claim topics e trusted issuers');
  console.log('    3. Unpause os tokenIds (agent chama unpause(0) e unpause(1))');
  console.log('    4. Mint tokens para investidores verificados');
  console.log('');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
