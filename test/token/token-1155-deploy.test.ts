import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import OnchainID from '@onchain-id/solidity';
import { deployIdentityProxy } from '../fixtures/deploy-full-suite.fixture';

/**
 * Este teste demonstra o deploy completo do Token1155 com 2 módulos de compliance:
 *
 *   tokenId 0 → MaxBalanceModule    (máximo 10.000 tokens por carteira)
 *   tokenId 1 → TransferLimitModule (máximo 5.000 por transferência)
 *
 * O fluxo de transferência do Token1155:
 *
 *   safeTransferFrom(from, to, id, amount, data)
 *     │
 *     ├─ 1. tokenId existe?                    → TokenIdDoesNotExist
 *     ├─ 2. tokenId não está pausado?           → TokenIdIsPaused
 *     ├─ 3. caller é owner ou approved?         → CallerNotOwnerOrApproved
 *     ├─ 4. to != address(0)?                   → ERC1155TransferToZeroAddress
 *     ├─ 5. from/to não estão frozen?            → WalletIsFrozen
 *     ├─ 6. saldo livre suficiente?             → InsufficientUnfrozenBalance
 *     ├─ 7. to tem identidade verificada?       → IdentityNotVerified
 *     ├─ 8. compliance.canTransfer()?           → TransferNotCompliant   ← MÓDULOS CHECAM AQUI
 *     │      └─ MaxBalanceModule.moduleCheck()
 *     │      └─ TransferLimitModule.moduleCheck()
 *     └─ 9. Transfere + compliance.transferred()
 */

async function deployToken1155WithModulesFixture() {
  const [deployer, tokenAgent, claimIssuer, aliceWallet, bobWallet, charlieWallet] =
    await ethers.getSigners();
  const claimIssuerSigningKey = ethers.Wallet.createRandom();

  // --- Implementations ---
  const claimTopicsRegistryImpl = await ethers.deployContract('ClaimTopicsRegistry', deployer);
  const trustedIssuersRegistryImpl = await ethers.deployContract('TrustedIssuersRegistry', deployer);
  const identityRegistryStorageImpl = await ethers.deployContract('IdentityRegistryStorage', deployer);
  const identityRegistryImpl = await ethers.deployContract('IdentityRegistry', deployer);
  const modularComplianceImpl = await ethers.deployContract('ModularCompliance', deployer);
  const tokenImpl = await ethers.deployContract('Token', deployer);
  const token1155Impl = await ethers.deployContract('Token1155', deployer);

  // --- Identity infrastructure ---
  const identityImpl = await new ethers.ContractFactory(
    OnchainID.contracts.Identity.abi, OnchainID.contracts.Identity.bytecode, deployer,
  ).deploy(deployer.address, true);
  const identityImplAuth = await new ethers.ContractFactory(
    OnchainID.contracts.ImplementationAuthority.abi, OnchainID.contracts.ImplementationAuthority.bytecode, deployer,
  ).deploy(identityImpl.address);

  // --- TREXImplementationAuthority ---
  const trexIA = await ethers.deployContract(
    'TREXImplementationAuthority',
    [true, ethers.constants.AddressZero, ethers.constants.AddressZero], deployer,
  );
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

  // --- Registries ---
  const claimTopicsRegistry = await ethers
    .deployContract('ClaimTopicsRegistryProxy', [trexIA.address], deployer)
    .then((p) => ethers.getContractAt('ClaimTopicsRegistry', p.address));
  const trustedIssuersRegistry = await ethers
    .deployContract('TrustedIssuersRegistryProxy', [trexIA.address], deployer)
    .then((p) => ethers.getContractAt('TrustedIssuersRegistry', p.address));
  const identityRegistryStorage = await ethers
    .deployContract('IdentityRegistryStorageProxy', [trexIA.address], deployer)
    .then((p) => ethers.getContractAt('IdentityRegistryStorage', p.address));
  const identityRegistry = await ethers
    .deployContract('IdentityRegistryProxy', [
      trexIA.address, trustedIssuersRegistry.address, claimTopicsRegistry.address, identityRegistryStorage.address,
    ], deployer)
    .then((p) => ethers.getContractAt('IdentityRegistry', p.address));

  await identityRegistryStorage.bindIdentityRegistry(identityRegistry.address);

  // --- Compliance Modules ---
  const maxBalanceModule = await ethers.deployContract('MaxBalanceModule', deployer);
  const transferLimitModule = await ethers.deployContract('TransferLimitModule', deployer);

  // --- Compliance 0: MaxBalanceModule (max 10.000) ---
  const compliance0 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((p) => ethers.getContractAt('ModularCompliance', p.address));
  await compliance0.addModule(maxBalanceModule.address);
  await compliance0.callModuleFunction(
    maxBalanceModule.interface.encodeFunctionData('setMaxBalance', [10000]),
    maxBalanceModule.address,
  );

  // --- Compliance 1: TransferLimitModule (max 5.000) ---
  const compliance1 = await ethers
    .deployContract('ModularComplianceProxy', [trexIA.address], deployer)
    .then((p) => ethers.getContractAt('ModularCompliance', p.address));
  await compliance1.addModule(transferLimitModule.address);
  await compliance1.callModuleFunction(
    transferLimitModule.interface.encodeFunctionData('setTransferLimit', [5000]),
    transferLimitModule.address,
  );

  // --- Token1155 ---
  const tokenOID = await deployIdentityProxy(identityImplAuth.address, deployer.address, deployer);
  const token1155 = await ethers
    .deployContract('Token1155Proxy', [
      trexIA.address, identityRegistry.address, 'SecurityToken1155', 'ST1155', tokenOID.address,
    ], deployer)
    .then((p) => ethers.getContractAt('Token1155', p.address));

  // Create tokenIds
  await token1155.createTokenId(18, compliance0.address); // tokenId 0
  await token1155.createTokenId(8, compliance1.address);  // tokenId 1

  // --- Setup agents ---
  await token1155.addAgent(tokenAgent.address);
  await identityRegistry.addAgent(tokenAgent.address);
  await identityRegistry.addAgent(token1155.address);

  // --- Claims setup ---
  const claimTopics = [ethers.utils.id('CLAIM_TOPIC')];
  await claimTopicsRegistry.addClaimTopic(claimTopics[0]);

  const claimIssuerContract = await ethers.deployContract('ClaimIssuer', [claimIssuer.address], claimIssuer);
  await claimIssuerContract.connect(claimIssuer).addKey(
    ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [claimIssuerSigningKey.address])), 3, 1,
  );
  await trustedIssuersRegistry.addTrustedIssuer(claimIssuerContract.address, claimTopics);

  // --- Register investor identities ---
  const aliceIdentity = await deployIdentityProxy(identityImplAuth.address, aliceWallet.address, deployer);
  const bobIdentity = await deployIdentityProxy(identityImplAuth.address, bobWallet.address, deployer);

  await identityRegistry.connect(tokenAgent).batchRegisterIdentity(
    [aliceWallet.address, bobWallet.address],
    [aliceIdentity.address, bobIdentity.address],
    [42, 666],
  );

  // Add claims for alice and bob
  for (const { wallet, identity } of [
    { wallet: aliceWallet, identity: aliceIdentity },
    { wallet: bobWallet, identity: bobIdentity },
  ]) {
    const claim = {
      data: ethers.utils.hexlify(ethers.utils.toUtf8Bytes('Some claim public data.')),
      issuer: claimIssuerContract.address,
      topic: claimTopics[0],
      scheme: 1,
      identity: identity.address,
      signature: '',
    };
    claim.signature = await claimIssuerSigningKey.signMessage(
      ethers.utils.arrayify(
        ethers.utils.keccak256(
          ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]),
        ),
      ),
    );
    await identity.connect(wallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, '');
  }

  // Mint initial tokens and unpause
  // Note: mints also go through compliance canTransfer(address(0), to, amount)
  // tokenId 0 has MaxBalanceModule (max 10.000 per operation) — fine
  // tokenId 1 has TransferLimitModule (max 5.000 per operation) — must mint in batches
  await token1155.connect(tokenAgent).mint(aliceWallet.address, 5000, 0);
  await token1155.connect(tokenAgent).mint(bobWallet.address, 3000, 0);
  // Mint tokenId 1 in batches of 5000 (within transfer limit)
  await token1155.connect(tokenAgent).mint(aliceWallet.address, 5000, 1);
  await token1155.connect(tokenAgent).mint(aliceWallet.address, 3000, 1); // alice total: 8000
  await token1155.connect(tokenAgent).mint(bobWallet.address, 2000, 1);
  await token1155.connect(tokenAgent).unpause(0);
  await token1155.connect(tokenAgent).unpause(1);

  return {
    accounts: { deployer, tokenAgent, aliceWallet, bobWallet, charlieWallet },
    suite: { token1155, compliance0, compliance1, identityRegistry },
    modules: { maxBalanceModule, transferLimitModule },
  };
}

describe('Token1155 Deploy with Compliance Modules', () => {
  describe('Setup validation', () => {
    it('should deploy with correct name, symbol, and 2 tokenIds', async () => {
      const { suite: { token1155 } } = await loadFixture(deployToken1155WithModulesFixture);
      expect(await token1155.name()).to.equal('SecurityToken1155');
      expect(await token1155.symbol()).to.equal('ST1155');
      expect(await token1155.getTokenIdCount()).to.equal(2);
    });

    it('should have correct compliance bound per tokenId', async () => {
      const { suite: { token1155, compliance0, compliance1 } } = await loadFixture(deployToken1155WithModulesFixture);
      expect(await token1155.tokenCompliance(0)).to.equal(compliance0.address);
      expect(await token1155.tokenCompliance(1)).to.equal(compliance1.address);
    });

    it('should have modules configured correctly', async () => {
      const {
        suite: { compliance0, compliance1 },
        modules: { maxBalanceModule, transferLimitModule },
      } = await loadFixture(deployToken1155WithModulesFixture);

      expect(await maxBalanceModule.getMaxBalance(compliance0.address)).to.equal(10000);
      expect(await transferLimitModule.getTransferLimit(compliance1.address)).to.equal(5000);
    });

    it('should have initial balances after mint', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(5000);
      expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(3000);
      expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(8000);
      expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(2000);
    });
  });

  describe('MaxBalanceModule (tokenId 0)', () => {
    it('should allow transfer within max balance', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Bob has 3000, receiving 2000 → 5000 (within 10.000 max)
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 2000, '0x');
      expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(5000);
    });

    it('should block mint exceeding max balance', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, tokenAgent },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Alice has 5000, minting 10001 would exceed max 10.000 per tx check
      await expect(
        token1155.connect(tokenAgent).mint(aliceWallet.address, 10001, 0),
      ).to.be.revertedWithCustomError(token1155, 'TransferNotCompliant');
    });

    it('should block transfer exceeding max balance', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Mint more to alice so she has plenty to send
      await token1155.connect(tokenAgent).mint(aliceWallet.address, 5000, 0); // alice=10000

      // Try to send 10001 at once → exceeds MaxBalance module check (_value > max)
      await expect(
        token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 10001, '0x'),
      ).to.be.revertedWithCustomError(token1155, 'InsufficientUnfrozenBalance');
    });
  });

  describe('TransferLimitModule (tokenId 1)', () => {
    it('should allow transfer within limit', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Transfer 5000 (exactly at limit)
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 5000, '0x');
      expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(3000);
      expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(7000);
    });

    it('should block transfer exceeding limit', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Transfer 5001 exceeds TransferLimit of 5000
      await expect(
        token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 5001, '0x'),
      ).to.be.revertedWithCustomError(token1155, 'TransferNotCompliant');
    });

    it('should allow multiple transfers each within limit', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // 2 transfers of 4000 each (total 8000), each within 5000 limit
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 4000, '0x');
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 4000, '0x');
      expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(0);
      expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(10000);
    });
  });

  describe('Cross-tokenId compliance isolation', () => {
    it('tokenId 0 module should not affect tokenId 1', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // tokenId 1 has TransferLimitModule (max 5000), NOT MaxBalanceModule
      // So multiple transfers can push balance above 10.000 (no max balance check on tokenId 1)
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 4000, '0x');
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 4000, '0x');
      // Bob now has 10.000 on tokenId 1 — no MaxBalance restriction here
      expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(10000);
    });

    it('tokenId 1 module should not affect tokenId 0', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // tokenId 0 has MaxBalanceModule, NOT TransferLimitModule
      // So large single transfers (> 5000) are allowed if within max balance
      await token1155.connect(tokenAgent).mint(aliceWallet.address, 4000, 0); // alice = 9000
      // Transfer 9000 at once — no transfer limit on tokenId 0
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 9000, '0x');
      expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(12000);
    });
  });

  describe('Module reconfiguration', () => {
    it('owner can update max balance limit', async () => {
      const {
        suite: { token1155, compliance0 },
        modules: { maxBalanceModule },
        accounts: { deployer, aliceWallet, tokenAgent },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Lower max balance to 5000
      await compliance0.connect(deployer).callModuleFunction(
        maxBalanceModule.interface.encodeFunctionData('setMaxBalance', [5000]),
        maxBalanceModule.address,
      );
      expect(await maxBalanceModule.getMaxBalance(compliance0.address)).to.equal(5000);

      // Now minting 5001 should fail
      await expect(
        token1155.connect(tokenAgent).mint(aliceWallet.address, 5001, 0),
      ).to.be.revertedWithCustomError(token1155, 'TransferNotCompliant');
    });

    it('owner can update transfer limit', async () => {
      const {
        suite: { token1155, compliance1 },
        modules: { transferLimitModule },
        accounts: { deployer, aliceWallet, bobWallet },
      } = await loadFixture(deployToken1155WithModulesFixture);

      // Lower transfer limit to 1000
      await compliance1.connect(deployer).callModuleFunction(
        transferLimitModule.interface.encodeFunctionData('setTransferLimit', [1000]),
        transferLimitModule.address,
      );

      // Transfer 1001 should now fail
      await expect(
        token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 1001, '0x'),
      ).to.be.revertedWithCustomError(token1155, 'TransferNotCompliant');

      // But 1000 should work
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 1000, '0x');
      expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(3000);
    });
  });
});
