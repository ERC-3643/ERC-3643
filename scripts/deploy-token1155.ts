/**
 * Deploy Token1155 Suite
 *
 * This script deploys a complete regulated ERC-1155 token (T-REX)
 * with 2 tokenIds, each with different compliance modules:
 *
 *   tokenId 0 (18 decimals) → MaxBalanceModule  (max 10,000 tokens per wallet)
 *   tokenId 1 (8 decimals)  → TransferLimitModule (max 5,000 per transfer)
 *
 * Deployment architecture:
 *
 *   ┌──────────────────────────────────────────────────────────┐
 *   │                  TREXImplementationAuthority              │
 *   │  (registers all contract implementations)                │
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
 * Usage:
 *   npx hardhat run scripts/deploy-token1155.ts
 *   npx hardhat run scripts/deploy-token1155.ts --network <network>
 */

import { ethers } from 'hardhat';
import OnchainID from '@onchain-id/solidity';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deployer:', deployer.address);
  console.log('Balance:', ethers.utils.formatEther(await deployer.getBalance()), 'ETH\n');

  // =========================================================================
  // STEP 1: Deploy implementations (logic contracts used by proxies)
  // =========================================================================
  console.log('=== STEP 1: Implementations ===');

  const claimTopicsRegistryImpl = await ethers.deployContract('ClaimTopicsRegistry', deployer);
  const trustedIssuersRegistryImpl = await ethers.deployContract('TrustedIssuersRegistry', deployer);
  const identityRegistryStorageImpl = await ethers.deployContract('IdentityRegistryStorage', deployer);
  const identityRegistryImpl = await ethers.deployContract('IdentityRegistry', deployer);
  const modularComplianceImpl = await ethers.deployContract('ModularCompliance', deployer);
  const tokenImpl = await ethers.deployContract('Token', deployer);
  const token1155Impl = await ethers.deployContract('Token1155', deployer);
  console.log('  Token1155 implementation:', token1155Impl.address);

  // =========================================================================
  // STEP 2: TREXImplementationAuthority — Registers all implementations
  // =========================================================================
  console.log('\n=== STEP 2: Implementation Authority ===');

  const trexIA = await ethers.deployContract(
    'TREXImplementationAuthority',
    [true, ethers.constants.AddressZero, ethers.constants.AddressZero],
    deployer,
  );

  // Register version with ALL implementations (including Token1155)
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
  // STEP 3: Deploy identity infrastructure (registries)
  // =========================================================================
  console.log('\n=== STEP 3: Registry Infrastructure ===');

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
  // STEP 4: Deploy compliance modules
  // =========================================================================
  console.log('\n=== STEP 4: Compliance Modules ===');

  // Module 1: MaxBalanceModule — limits max balance per wallet
  const maxBalanceModule = await ethers.deployContract('MaxBalanceModule', deployer);
  console.log('  MaxBalanceModule:', maxBalanceModule.address);

  // Module 2: TransferLimitModule — limits max amount per transfer
  const transferLimitModule = await ethers.deployContract('TransferLimitModule', deployer);
  console.log('  TransferLimitModule:', transferLimitModule.address);

  // =========================================================================
  // STEP 5: Deploy ModularCompliance (one per tokenId)
  // =========================================================================
  console.log('\n=== STEP 5: Modular Compliance (1 per tokenId) ===');

  // Compliance for tokenId 0: uses MaxBalanceModule
  const compliance0 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('ModularCompliance', proxy.address));
  console.log('  Compliance0 (tokenId 0):', compliance0.address);

  // Add MaxBalanceModule and configure max = 10,000
  await compliance0.addModule(maxBalanceModule.address);
  await compliance0.callModuleFunction(
    maxBalanceModule.interface.encodeFunctionData('setMaxBalance', [10000]),
    maxBalanceModule.address,
  );
  console.log('    └─ MaxBalanceModule added (max: 10,000)');

  // Compliance for tokenId 1: uses TransferLimitModule
  const compliance1 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((proxy) => ethers.getContractAt('ModularCompliance', proxy.address));
  console.log('  Compliance1 (tokenId 1):', compliance1.address);

  // Add TransferLimitModule and configure limit = 5,000
  await compliance1.addModule(transferLimitModule.address);
  await compliance1.callModuleFunction(
    transferLimitModule.interface.encodeFunctionData('setTransferLimit', [5000]),
    transferLimitModule.address,
  );
  console.log('    └─ TransferLimitModule added (max: 5,000)');

  // =========================================================================
  // STEP 6: Deploy Token1155 via proxy
  // =========================================================================
  console.log('\n=== STEP 6: Token1155 ===');

  // Deploy OnchainID for the token (required by ERC-3643)
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
  // STEP 7: Create tokenIds (each with its own compliance)
  // =========================================================================
  console.log('\n=== STEP 7: Create TokenIds ===');

  // tokenId 0: 18 decimals, compliance with MaxBalanceModule
  await token1155.createTokenId(18, compliance0.address);
  console.log('  tokenId 0: 18 decimals → MaxBalanceModule (max 10,000/wallet)');

  // tokenId 1: 8 decimals, compliance with TransferLimitModule
  await token1155.createTokenId(8, compliance1.address);
  console.log('  tokenId 1: 8 decimals  → TransferLimitModule (max 5,000/tx)');

  // Both start paused (default behavior of createTokenId)
  console.log('  Status: both paused (default)');
  console.log('  Total tokenIds:', (await token1155.getTokenIdCount()).toString());

  // =========================================================================
  // STEP 8: Configure agents
  // =========================================================================
  console.log('\n=== STEP 8: Agents ===');

  // Deployer adds itself as agent (in production, use a separate account)
  await token1155.addAgent(deployer.address);
  await identityRegistry.addAgent(deployer.address);
  await identityRegistry.addAgent(token1155.address);
  console.log('  Agent added:', deployer.address);

  // =========================================================================
  // SUMMARY
  // =========================================================================
  console.log('\n══════════════════════════════════════════════════');
  console.log('  DEPLOY COMPLETE!');
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
  console.log('               Module:     MaxBalanceModule (max: 10,000)');
  console.log('  tokenId 1 → Compliance: ', compliance1.address);
  console.log('               Module:     TransferLimitModule (max: 5,000)');
  console.log('');
  console.log('  Next steps:');
  console.log('    1. Register investor identities in IdentityRegistry');
  console.log('    2. Configure claim topics and trusted issuers');
  console.log('    3. Unpause tokenIds (agent calls unpause(0) and unpause(1))');
  console.log('    4. Mint tokens to verified investors');
  console.log('');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
