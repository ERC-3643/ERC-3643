import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployFullSuiteFixture } from '../fixtures/deploy-full-suite.fixture';

describe('IdentityRegistry (pluggable IIdentityVerifier)', () => {
  describe('.setIdentityVerifier()', () => {
    describe('when sender is not the owner', () => {
      it('should revert', async () => {
        const {
          suite: { identityRegistry },
          accounts: { anotherWallet },
        } = await loadFixture(deployFullSuiteFixture);

        // Intentionally asserts *any* revert rather than the exact OZ 4.x
        // "Ownable: caller is not the owner" string, so the test survives a
        // future OZ 5.x migration (which uses a custom error instead).
        await expect(identityRegistry.connect(anotherWallet).setIdentityVerifier(ethers.constants.AddressZero)).to.be
          .reverted;
      });
    });

    describe('when sender is the owner', () => {
      it('should set the identity verifier and emit IdentityVerifierSet', async () => {
        const {
          suite: { identityRegistry },
          accounts: { deployer },
        } = await loadFixture(deployFullSuiteFixture);

        const verifier = await ethers.deployContract('FixedAnswerVerifier', [true]);

        const tx = await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);
        await expect(tx).to.emit(identityRegistry, 'IdentityVerifierSet').withArgs(verifier.address);

        expect(await identityRegistry.identityVerifier()).to.equal(verifier.address);
      });

      it('should clear the identity verifier when set to address(0)', async () => {
        const {
          suite: { identityRegistry },
          accounts: { deployer },
        } = await loadFixture(deployFullSuiteFixture);

        const verifier = await ethers.deployContract('FixedAnswerVerifier', [true]);
        await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);
        expect(await identityRegistry.identityVerifier()).to.equal(verifier.address);

        const tx = await identityRegistry.connect(deployer).setIdentityVerifier(ethers.constants.AddressZero);
        await expect(tx).to.emit(identityRegistry, 'IdentityVerifierSet').withArgs(ethers.constants.AddressZero);
        expect(await identityRegistry.identityVerifier()).to.equal(ethers.constants.AddressZero);
      });
    });
  });

  describe('.isVerified() with no pluggable verifier configured', () => {
    it('should match default ONCHAINID-based behaviour (alice with valid claims is verified)', async () => {
      const {
        suite: { identityRegistry },
        accounts: { aliceWallet },
      } = await loadFixture(deployFullSuiteFixture);

      expect(await identityRegistry.identityVerifier()).to.equal(ethers.constants.AddressZero);
      await expect(identityRegistry.isVerified(aliceWallet.address)).to.eventually.be.true;
    });
  });

  describe('.isVerified() when a FixedAnswerVerifier(true) is configured', () => {
    it('should return true for a wallet with NO registered ONCHAINID (bypasses built-in logic)', async () => {
      const {
        suite: { identityRegistry },
        accounts: { deployer, anotherWallet },
      } = await loadFixture(deployFullSuiteFixture);

      // anotherWallet has no identity registered; default path would return false.
      expect(await identityRegistry.contains(anotherWallet.address)).to.be.false;
      await expect(identityRegistry.isVerified(anotherWallet.address)).to.eventually.be.false;

      const verifier = await ethers.deployContract('FixedAnswerVerifier', [true]);
      await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);

      await expect(identityRegistry.isVerified(anotherWallet.address)).to.eventually.be.true;
    });
  });

  describe('.isVerified() when a FixedAnswerVerifier(false) is configured', () => {
    it('should return false for a wallet WITH valid ONCHAINID claims (delegation overrides default)', async () => {
      const {
        suite: { identityRegistry },
        accounts: { deployer, aliceWallet },
      } = await loadFixture(deployFullSuiteFixture);

      // alice has valid claims; default path returns true.
      await expect(identityRegistry.isVerified(aliceWallet.address)).to.eventually.be.true;

      const verifier = await ethers.deployContract('FixedAnswerVerifier', [false]);
      await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);

      await expect(identityRegistry.isVerified(aliceWallet.address)).to.eventually.be.false;
    });
  });

  describe('.isVerified() after clearing the verifier', () => {
    it('should restore default ONCHAINID-based behaviour', async () => {
      const {
        suite: { identityRegistry },
        accounts: { deployer, aliceWallet },
      } = await loadFixture(deployFullSuiteFixture);

      const falseVerifier = await ethers.deployContract('FixedAnswerVerifier', [false]);
      await identityRegistry.connect(deployer).setIdentityVerifier(falseVerifier.address);
      await expect(identityRegistry.isVerified(aliceWallet.address)).to.eventually.be.false;

      await identityRegistry.connect(deployer).setIdentityVerifier(ethers.constants.AddressZero);
      await expect(identityRegistry.isVerified(aliceWallet.address)).to.eventually.be.true;
    });
  });

  describe('.setIdentityVerifier() input sanity', () => {
    it('should revert when passing an EOA (no runtime code)', async () => {
      const {
        suite: { identityRegistry },
        accounts: { deployer, anotherWallet },
      } = await loadFixture(deployFullSuiteFixture);

      await expect(identityRegistry.connect(deployer).setIdentityVerifier(anotherWallet.address)).to.be.revertedWith(
        'verifier must be a contract',
      );
    });

    it('should be a no-op when setting the same verifier twice (no extra event)', async () => {
      const {
        suite: { identityRegistry },
        accounts: { deployer },
      } = await loadFixture(deployFullSuiteFixture);

      const verifier = await ethers.deployContract('FixedAnswerVerifier', [true]);
      await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);

      // Second call is a no-op: no state change, no event emitted.
      const tx = await identityRegistry.connect(deployer).setIdentityVerifier(verifier.address);
      const receipt = await tx.wait();
      const events = (receipt.events ?? []).filter((e) => e.event === 'IdentityVerifierSet');
      expect(events.length).to.equal(0);
    });
  });

  describe('.isVerified() gas (regression guard)', () => {
    // Guards against accidental layout/indirection changes that add unexpected
    // overhead to the default (verifier unset) path. Baseline for aliceWallet
    // `estimateGas.isVerified` on this branch is ~163k gas (21k tx base +
    // ONCHAINID lookup + one trusted-issuer `isClaimValid` external call + one
    // claim fetch). We allow ~17k headroom; if this guard fires, a change has
    // bloated the default path and deserves a look.
    it('default path stays under 180k gas for a single-claim verification', async () => {
      const {
        suite: { identityRegistry },
        accounts: { aliceWallet },
      } = await loadFixture(deployFullSuiteFixture);

      expect(await identityRegistry.identityVerifier()).to.equal(ethers.constants.AddressZero);
      const gas = await identityRegistry.estimateGas.isVerified(aliceWallet.address);
      expect(gas.toNumber()).to.be.lessThan(180_000);
    });
  });
});
