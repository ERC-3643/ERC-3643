import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { deployFullSuiteFixture } from './fixtures/deploy-full-suite.fixture';

const tokenDetails = (owner: string, name: string, irs: string = ethers.constants.AddressZero, irAgents: string[] = []) => ({
  owner,
  name,
  symbol: name.toUpperCase().slice(0, 4),
  decimals: 8,
  irs,
  ONCHAINID: ethers.constants.AddressZero,
  irAgents,
  tokenAgents: [],
  complianceModules: [],
  complianceSettings: [],
});

const emptyClaims = { claimTopics: [], issuers: [], issuerClaims: [] };

async function setup() {
  const context = await loadFixture(deployFullSuiteFixture);
  // public deployment enabled: anyone can deploy for themselves
  const gateway = await ethers.deployContract('TREXGateway', [context.factories.trexFactory.address, true], context.accounts.deployer);
  await context.factories.trexFactory.transferOwnership(gateway.address);
  return { context, gateway };
}

async function irsOfLastDeployment(context: any, owner: string, name: string) {
  const salt = owner.toLowerCase() + name;
  const tokenAddr = await context.factories.trexFactory.getToken(salt);
  const token = await ethers.getContractAt('Token', tokenAddr);
  const ir = await ethers.getContractAt('IdentityRegistry', await token.identityRegistry());
  return ir.identityStorage();
}

describe('TREXGateway - IRS access control', () => {
  it('registers a freshly deployed IRS with the token owner as IRS owner', async () => {
    const { context, gateway } = await setup();
    const alice = context.accounts.aliceWallet;

    const tx = await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
    const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

    await expect(tx).to.emit(gateway, 'IRSRegistered').withArgs(irs, alice.address);
    expect(await gateway.getIRSOwner(irs)).to.equal(alice.address);
    expect(await gateway.isIRSUsageAuthorized(irs, alice.address)).to.be.true;
    expect(await gateway.isIRSUsageAuthorized(irs, context.accounts.bobWallet.address)).to.be.false;
  });

  it('blocks another token owner from binding to an IRS they do not own (the original issue)', async () => {
    const { context, gateway } = await setup();
    const alice = context.accounts.aliceWallet;
    const bob = context.accounts.bobWallet;

    await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
    const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

    await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken', irs, [bob.address]), emptyClaims))
      .to.be.revertedWithCustomError(gateway, 'IRSUsageNotAuthorized')
      .withArgs(irs, bob.address);
  });

  it('lets the IRS owner reuse their own IRS for a second token', async () => {
    const { context, gateway } = await setup();
    const alice = context.accounts.aliceWallet;

    await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
    const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

    await expect(gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken2', irs), emptyClaims)).to.not.be.reverted;
    expect(await irsOfLastDeployment(context, alice.address, 'AliceToken2')).to.equal(irs);
    // second deployment did not re-register / overwrite the IRS owner
    expect(await gateway.getIRSOwner(irs)).to.equal(alice.address);
  });

  it('rejects an unregistered IRS', async () => {
    const { context, gateway } = await setup();
    const bob = context.accounts.bobWallet;
    const legacyIrs = context.suite.identityRegistryStorage.address;

    await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken', legacyIrs), emptyClaims))
      .to.be.revertedWithCustomError(gateway, 'IRSNotRegistered')
      .withArgs(legacyIrs);
  });

  describe('authorizeIRSUsage / revokeIRSUsage', () => {
    it('only the IRS owner can authorize', async () => {
      const { context, gateway } = await setup();
      const alice = context.accounts.aliceWallet;
      const bob = context.accounts.bobWallet;
      await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
      const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

      await expect(gateway.connect(bob).authorizeIRSUsage(irs, bob.address)).to.be.revertedWithCustomError(gateway, 'OnlyIRSOwnerCall');
      // gateway owner/admin is not the IRS owner either
      await expect(gateway.connect(context.accounts.deployer).authorizeIRSUsage(irs, bob.address)).to.be.revertedWithCustomError(
        gateway,
        'OnlyIRSOwnerCall',
      );
    });

    it('authorized token owner can reuse the IRS, revoked one cannot', async () => {
      const { context, gateway } = await setup();
      const alice = context.accounts.aliceWallet;
      const bob = context.accounts.bobWallet;
      await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
      const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

      await expect(gateway.connect(alice).authorizeIRSUsage(irs, bob.address)).to.emit(gateway, 'IRSUsageAuthorized').withArgs(irs, bob.address);
      await expect(gateway.connect(alice).authorizeIRSUsage(irs, bob.address)).to.be.revertedWithCustomError(gateway, 'IRSUsageAlreadyAuthorized');
      expect(await gateway.isIRSUsageAuthorized(irs, bob.address)).to.be.true;

      await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken', irs), emptyClaims)).to.not.be.reverted;
      expect(await irsOfLastDeployment(context, bob.address, 'BobToken')).to.equal(irs);
      // sharing does not transfer IRS ownership
      expect(await gateway.getIRSOwner(irs)).to.equal(alice.address);

      await expect(gateway.connect(alice).revokeIRSUsage(irs, bob.address)).to.emit(gateway, 'IRSUsageRevoked').withArgs(irs, bob.address);
      await expect(gateway.connect(alice).revokeIRSUsage(irs, bob.address)).to.be.revertedWithCustomError(gateway, 'IRSUsageNotAuthorized');
      await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken2', irs), emptyClaims)).to.be.revertedWithCustomError(
        gateway,
        'IRSUsageNotAuthorized',
      );
    });
  });

  describe('transferIRSOwnership', () => {
    it('moves control of the IRS sharing rules', async () => {
      const { context, gateway } = await setup();
      const alice = context.accounts.aliceWallet;
      const bob = context.accounts.bobWallet;
      await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
      const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');

      await expect(gateway.connect(bob).transferIRSOwnership(irs, bob.address)).to.be.revertedWithCustomError(gateway, 'OnlyIRSOwnerCall');
      await expect(gateway.connect(alice).transferIRSOwnership(irs, ethers.constants.AddressZero)).to.be.revertedWithCustomError(gateway, 'ZeroAddress');
      await expect(gateway.connect(alice).transferIRSOwnership(irs, bob.address))
        .to.emit(gateway, 'IRSOwnershipTransferred')
        .withArgs(irs, alice.address, bob.address);

      expect(await gateway.getIRSOwner(irs)).to.equal(bob.address);
      await expect(gateway.connect(alice).authorizeIRSUsage(irs, alice.address)).to.be.revertedWithCustomError(gateway, 'OnlyIRSOwnerCall');
      await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken', irs), emptyClaims)).to.not.be.reverted;
    });
  });

  describe('recoverIRSOwnership', () => {
    it('transfers Ownable ownership of the IRS from the factory to the IRS owner, after which it cannot be reused through the factory', async () => {
      const { context, gateway } = await setup();
      const alice = context.accounts.aliceWallet;
      const bob = context.accounts.bobWallet;
      await gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken'), emptyClaims);
      const irs = await irsOfLastDeployment(context, alice.address, 'AliceToken');
      const irsContract = await ethers.getContractAt('IdentityRegistryStorage', irs);
      expect(await irsContract.owner()).to.equal(context.factories.trexFactory.address);

      await expect(gateway.connect(bob).recoverIRSOwnership(irs)).to.be.revertedWithCustomError(gateway, 'OnlyIRSOwnerCall');
      await expect(gateway.connect(alice).recoverIRSOwnership(irs)).to.emit(gateway, 'IRSOwnershipRecovered').withArgs(irs, alice.address);
      expect(await irsContract.owner()).to.equal(alice.address);

      await expect(gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken2', irs), emptyClaims))
        .to.be.revertedWithCustomError(gateway, 'IRSNotOwnedByFactory')
        .withArgs(irs);

      // giving ownership back to the factory re-enables reuse, registration was kept
      await irsContract.connect(alice).transferOwnership(context.factories.trexFactory.address);
      await expect(gateway.connect(alice).deployTREXSuite(tokenDetails(alice.address, 'AliceToken2', irs), emptyClaims)).to.not.be.reverted;
    });
  });

  describe('registerIRS (legacy IRS onboarding)', () => {
    it('admin can register a pre-existing IRS owned by the factory', async () => {
      const { context, gateway } = await setup();
      const bob = context.accounts.bobWallet;
      const legacyIrs = context.suite.identityRegistryStorage;

      // not owned by factory yet
      await expect(gateway.registerIRS(legacyIrs.address, bob.address)).to.be.revertedWithCustomError(gateway, 'IRSNotOwnedByFactory');

      await legacyIrs.connect(context.accounts.deployer).transferOwnership(context.factories.trexFactory.address);

      await expect(gateway.connect(bob).registerIRS(legacyIrs.address, bob.address)).to.be.revertedWithCustomError(gateway, 'OnlyAdminCall');
      await expect(gateway.registerIRS(legacyIrs.address, bob.address)).to.emit(gateway, 'IRSRegistered').withArgs(legacyIrs.address, bob.address);
      await expect(gateway.registerIRS(legacyIrs.address, bob.address)).to.be.revertedWithCustomError(gateway, 'IRSAlreadyRegistered');

      await expect(gateway.connect(bob).deployTREXSuite(tokenDetails(bob.address, 'BobToken', legacyIrs.address), emptyClaims)).to.not.be.reverted;
      expect(await irsOfLastDeployment(context, bob.address, 'BobToken')).to.equal(legacyIrs.address);
    });
  });
});
