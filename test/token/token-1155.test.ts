import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployFullSuite1155Fixture } from '../fixtures/deploy-full-suite-1155.fixture';

describe('Token1155', () => {
  describe('.init()', () => {
    it('should set name, symbol, identityRegistry', async () => {
      const {
        suite: { token1155, identityRegistry },
      } = await loadFixture(deployFullSuite1155Fixture);

      expect(await token1155.name()).to.equal('TREX1155');
      expect(await token1155.symbol()).to.equal('TREX1155');
      expect(await token1155.identityRegistry()).to.equal(identityRegistry.address);
      expect(await token1155.version()).to.equal('4.1.3');
    });
  });

  describe('.createTokenId()', () => {
    it('should create two tokenIds with correct decimals', async () => {
      const {
        suite: { token1155, compliance0, compliance1 },
      } = await loadFixture(deployFullSuite1155Fixture);

      expect(await token1155.tokenIdExists(0)).to.be.true;
      expect(await token1155.tokenIdExists(1)).to.be.true;
      expect(await token1155.tokenIdExists(2)).to.be.false;
      expect(await token1155.decimals(0)).to.equal(18);
      expect(await token1155.decimals(1)).to.equal(8);
      expect(await token1155.getTokenIdCount()).to.equal(2);
      expect(await token1155.tokenCompliance(0)).to.equal(compliance0.address);
      expect(await token1155.tokenCompliance(1)).to.equal(compliance1.address);
    });

    it('should revert if not owner', async () => {
      const {
        suite: { token1155, compliance0 },
        accounts: { aliceWallet },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(token1155.connect(aliceWallet).createTokenId(18, compliance0.address)).to.be.revertedWith(
        'Ownable: caller is not the owner',
      );
    });

    it('should revert if compliance is zero address', async () => {
      const {
        suite: { token1155 },
        accounts: { deployer },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(deployer).createTokenId(18, ethers.constants.AddressZero),
      ).to.be.revertedWithCustomError(token1155, 'ZeroAddress');
    });

    it('should revert if decimals > 18', async () => {
      const {
        suite: { token1155, compliance0 },
        accounts: { deployer },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(deployer).createTokenId(19, compliance0.address),
      ).to.be.revertedWithCustomError(token1155, 'DecimalsOutOfRange').withArgs(19);
    });
  });

  describe('ERC-1155 Standard', () => {
    describe('.balanceOf()', () => {
      it('should return correct balances', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(1000);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(500);
        expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(2000);
        expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(1000);
      });

      it('should revert for zero address', async () => {
        const {
          suite: { token1155 },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.balanceOf(ethers.constants.AddressZero, 0),
        ).to.be.revertedWithCustomError(token1155, 'ZeroAddress');
      });
    });

    describe('.balanceOfBatch()', () => {
      it('should return batch balances', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        const balances = await token1155.balanceOfBatch([aliceWallet.address, bobWallet.address], [0, 1]);
        expect(balances[0]).to.equal(1000);
        expect(balances[1]).to.equal(1000);
      });

      it('should revert if accounts and ids length mismatch', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.balanceOfBatch([aliceWallet.address, bobWallet.address], [0]),
        ).to.be.revertedWithCustomError(token1155, 'ArrayLengthMismatch');
      });
    });

    describe('.setApprovalForAll()', () => {
      it('should set operator approval', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).setApprovalForAll(bobWallet.address, true);
        expect(await token1155.isApprovedForAll(aliceWallet.address, bobWallet.address)).to.be.true;
      });

      it('should revert when approving self', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).setApprovalForAll(aliceWallet.address, true),
        ).to.be.revertedWithCustomError(token1155, 'SelfApproval');
      });

      it('should revoke approval and prevent operator transfer', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).setApprovalForAll(bobWallet.address, true);
        expect(await token1155.isApprovedForAll(aliceWallet.address, bobWallet.address)).to.be.true;

        await token1155.connect(aliceWallet).setApprovalForAll(bobWallet.address, false);
        expect(await token1155.isApprovedForAll(aliceWallet.address, bobWallet.address)).to.be.false;

        await expect(
          token1155.connect(bobWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'CallerNotOwnerOrApproved').withArgs(bobWallet.address);
      });
    });

    describe('.supportsInterface()', () => {
      it('should support IERC1155 interface', async () => {
        const {
          suite: { token1155 },
        } = await loadFixture(deployFullSuite1155Fixture);

        // IERC1155 interface id
        expect(await token1155.supportsInterface('0xd9b67a26')).to.be.true;
      });

      it('should support IERC1155MetadataURI interface', async () => {
        const {
          suite: { token1155 },
        } = await loadFixture(deployFullSuite1155Fixture);

        expect(await token1155.supportsInterface('0x0e89341c')).to.be.true;
      });

      it('should support IERC165 interface', async () => {
        const {
          suite: { token1155 },
        } = await loadFixture(deployFullSuite1155Fixture);

        expect(await token1155.supportsInterface('0x01ffc9a7')).to.be.true;
      });
    });

    describe('.safeTransferFrom()', () => {
      it('should transfer between verified addresses', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x');
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(900);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(600);
      });

      it('should revert when paused', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).pause(0);
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdIsPaused').withArgs(0);
      });

      it('should revert when sender is frozen', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).setAddressFrozen(aliceWallet.address, true);
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'WalletIsFrozen').withArgs(aliceWallet.address);
      });

      it('should revert when receiver is frozen', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).setAddressFrozen(bobWallet.address, true);
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'WalletIsFrozen').withArgs(bobWallet.address);
      });

      it('should revert when insufficient balance due to frozen tokens', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 950, 0);
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'InsufficientUnfrozenBalance').withArgs(aliceWallet.address, 0, 100, 50);
      });

      it('should revert when receiver not verified', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, charlieWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, charlieWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'IdentityNotVerified').withArgs(charlieWallet.address);
      });

      it('should allow approved operator to transfer', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).setApprovalForAll(bobWallet.address, true);
        await token1155.connect(bobWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x');
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(900);
      });

      it('should revert when caller is not owner or approved', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(bobWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'CallerNotOwnerOrApproved').withArgs(bobWallet.address);
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 99, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });

      it('should revert for transfer to zero address', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, ethers.constants.AddressZero, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'ERC1155TransferToZeroAddress');
      });
    });

    describe('.safeBatchTransferFrom()', () => {
      it('should batch transfer multiple tokenIds', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).safeBatchTransferFrom(aliceWallet.address, bobWallet.address, [0, 1], [100, 200], '0x');
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(900);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(600);
        expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(1800);
        expect(await token1155.balanceOf(bobWallet.address, 1)).to.equal(1200);
      });

      it('should revert if ids and amounts length mismatch', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).safeBatchTransferFrom(aliceWallet.address, bobWallet.address, [0, 1], [100], '0x'),
        ).to.be.revertedWithCustomError(token1155, 'ArrayLengthMismatch');
      });

      it('should work with empty arrays (no-op)', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(aliceWallet).safeBatchTransferFrom(aliceWallet.address, bobWallet.address, [], [], '0x');
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(1000);
      });
    });
  });

  describe('Per-tokenId Pause', () => {
    it('should pause and unpause individual tokenIds', async () => {
      const {
        suite: { token1155 },
        accounts: { tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      expect(await token1155.paused(0)).to.be.false;
      await token1155.connect(tokenAgent).pause(0);
      expect(await token1155.paused(0)).to.be.true;
      expect(await token1155.paused(1)).to.be.false;
    });

    it('pausing tokenId 0 should not affect tokenId 1 transfers', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await token1155.connect(tokenAgent).pause(0);

      // tokenId 0 should be blocked
      await expect(
        token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdIsPaused').withArgs(0);

      // tokenId 1 should still work
      await token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 100, '0x');
      expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(1900);
    });

    it('should revert when pausing already paused tokenId (double pause)', async () => {
      const {
        suite: { token1155 },
        accounts: { tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await token1155.connect(tokenAgent).pause(0);
      await expect(
        token1155.connect(tokenAgent).pause(0),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdIsPaused').withArgs(0);
    });

    it('should revert when unpausing already unpaused tokenId (double unpause)', async () => {
      const {
        suite: { token1155 },
        accounts: { tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).unpause(0),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdIsNotPaused').withArgs(0);
    });

    it('should revert when pausing non-existent tokenId', async () => {
      const {
        suite: { token1155 },
        accounts: { tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).pause(99),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
    });

    it('should revert when unpausing non-existent tokenId', async () => {
      const {
        suite: { token1155 },
        accounts: { tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).unpause(99),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
    });
  });

  describe('Freeze', () => {
    describe('.setAddressFrozen()', () => {
      it('should freeze an address globally', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).setAddressFrozen(aliceWallet.address, true);
        expect(await token1155.isFrozen(aliceWallet.address)).to.be.true;

        // Should block transfers on all tokenIds
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 0, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'WalletIsFrozen').withArgs(aliceWallet.address);
        await expect(
          token1155.connect(aliceWallet).safeTransferFrom(aliceWallet.address, bobWallet.address, 1, 100, '0x'),
        ).to.be.revertedWithCustomError(token1155, 'WalletIsFrozen').withArgs(aliceWallet.address);
      });
    });

    describe('.freezePartialTokens()', () => {
      it('should freeze partial tokens on a specific tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 500, 0);
        expect(await token1155.getFrozenTokens(aliceWallet.address, 0)).to.equal(500);
        expect(await token1155.getFrozenTokens(aliceWallet.address, 1)).to.equal(0);
      });

      it('should revert if amount exceeds available balance', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 1001, 0),
        ).to.be.revertedWithCustomError(token1155, 'FreezeAmountExceedsAvailable').withArgs(aliceWallet.address, 0, 1001, 1000);
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 100, 99),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });
    });

    describe('.unfreezePartialTokens()', () => {
      it('should unfreeze partial tokens', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 500, 0);
        await token1155.connect(tokenAgent).unfreezePartialTokens(aliceWallet.address, 200, 0);
        expect(await token1155.getFrozenTokens(aliceWallet.address, 0)).to.equal(300);
      });

      it('should revert when amount exceeds frozen tokens', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 500, 0);
        await expect(
          token1155.connect(tokenAgent).unfreezePartialTokens(aliceWallet.address, 600, 0),
        ).to.be.revertedWithCustomError(token1155, 'UnfreezeAmountExceedsFrozen').withArgs(aliceWallet.address, 0, 600, 500);
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).unfreezePartialTokens(aliceWallet.address, 100, 99),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });
    });

    describe('.batchSetAddressFrozen()', () => {
      it('should batch freeze addresses', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).batchSetAddressFrozen([aliceWallet.address, bobWallet.address], [true, true]);
        expect(await token1155.isFrozen(aliceWallet.address)).to.be.true;
        expect(await token1155.isFrozen(bobWallet.address)).to.be.true;
      });
    });
  });

  describe('Mint / Burn', () => {
    describe('.mint()', () => {
      it('should mint tokens', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).mint(aliceWallet.address, 500, 0);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(1500);
        expect(await token1155.totalSupply(0)).to.equal(2000);
      });

      it('should revert if identity not verified', async () => {
        const {
          suite: { token1155 },
          accounts: { charlieWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).mint(charlieWallet.address, 500, 0),
        ).to.be.revertedWithCustomError(token1155, 'IdentityNotVerified').withArgs(charlieWallet.address);
      });

      it('should revert if not agent', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(token1155.connect(aliceWallet).mint(aliceWallet.address, 500, 0)).to.be.revertedWith(
          'AgentRole: caller does not have the Agent role',
        );
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).mint(aliceWallet.address, 500, 99),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });
    });

    describe('.burn()', () => {
      it('should burn tokens', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).burn(aliceWallet.address, 200, 0);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(800);
        expect(await token1155.totalSupply(0)).to.equal(1300);
      });

      it('should unfreeze tokens if burn exceeds free balance', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 900, 0);
        await token1155.connect(tokenAgent).burn(aliceWallet.address, 200, 0);
        // Free was 100, burned 200, so 100 unfrozen. Frozen: 900 - 100 = 800
        expect(await token1155.getFrozenTokens(aliceWallet.address, 0)).to.equal(800);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(800);
      });

      it('should revert if burn more than balance', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).burn(aliceWallet.address, 2000, 0),
        ).to.be.revertedWithCustomError(token1155, 'BurnExceedsBalance').withArgs(aliceWallet.address, 0, 2000, 1000);
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(tokenAgent).burn(aliceWallet.address, 100, 99),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });
    });

    describe('.batchMint()', () => {
      it('should batch mint', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).batchMint([aliceWallet.address, bobWallet.address], [100, 200], 0);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(1100);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(700);
      });
    });

    describe('.batchBurn()', () => {
      it('should batch burn', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(tokenAgent).batchBurn([aliceWallet.address, bobWallet.address], [100, 200], 0);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(900);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(300);
      });
    });
  });

  describe('.forcedTransfer()', () => {
    it('should force transfer between verified addresses', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await token1155.connect(tokenAgent).forcedTransfer(aliceWallet.address, bobWallet.address, 200, 0);
      expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(800);
      expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(700);
    });

    it('should unfreeze tokens if needed', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await token1155.connect(tokenAgent).freezePartialTokens(aliceWallet.address, 900, 0);
      await token1155.connect(tokenAgent).forcedTransfer(aliceWallet.address, bobWallet.address, 200, 0);
      expect(await token1155.getFrozenTokens(aliceWallet.address, 0)).to.equal(800);
    });

    it('should revert if balance too low', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).forcedTransfer(aliceWallet.address, bobWallet.address, 5000, 0),
      ).to.be.revertedWithCustomError(token1155, 'InsufficientBalance').withArgs(aliceWallet.address, 0, 5000, 1000);
    });

    it('should revert for non-existent tokenId', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, bobWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).forcedTransfer(aliceWallet.address, bobWallet.address, 100, 99),
      ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
    });

    it('should revert if receiver identity not verified', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, charlieWallet, tokenAgent },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).forcedTransfer(aliceWallet.address, charlieWallet.address, 100, 0),
      ).to.be.revertedWithCustomError(token1155, 'IdentityNotVerified').withArgs(charlieWallet.address);
    });

    describe('.batchForcedTransfer()', () => {
      it('should batch force transfer', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, bobWallet, tokenAgent },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155
          .connect(tokenAgent)
          .batchForcedTransfer([aliceWallet.address, bobWallet.address], [bobWallet.address, aliceWallet.address], [100, 50], 0);
        expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(950);
        expect(await token1155.balanceOf(bobWallet.address, 0)).to.equal(550);
      });
    });
  });

  describe('.recoveryAddress()', () => {
    it('should recover all tokens across tokenIds', async () => {
      const {
        suite: { token1155, identityRegistry },
        accounts: { aliceWallet, davidWallet, tokenAgent },
        identities: { aliceIdentity },
      } = await loadFixture(deployFullSuite1155Fixture);

      // Add davidWallet as a management key (purpose 1) on aliceIdentity
      await aliceIdentity
        .connect(aliceWallet)
        .addKey(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [davidWallet.address])), 1, 1);

      const tx = await token1155.connect(tokenAgent).recoveryAddress(aliceWallet.address, davidWallet.address, aliceIdentity.address);
      await expect(tx).to.emit(token1155, 'RecoverySuccess');

      expect(await token1155.balanceOf(davidWallet.address, 0)).to.equal(1000);
      expect(await token1155.balanceOf(davidWallet.address, 1)).to.equal(2000);
      expect(await token1155.balanceOf(aliceWallet.address, 0)).to.equal(0);
      expect(await token1155.balanceOf(aliceWallet.address, 1)).to.equal(0);
    });

    it('should revert if lost wallet has no tokens', async () => {
      const {
        suite: { token1155 },
        accounts: { charlieWallet, davidWallet, tokenAgent },
        identities: { charlieIdentity },
      } = await loadFixture(deployFullSuite1155Fixture);

      await expect(
        token1155.connect(tokenAgent).recoveryAddress(charlieWallet.address, davidWallet.address, charlieIdentity.address),
      ).to.be.revertedWithCustomError(token1155, 'NoTokensToRecover').withArgs(charlieWallet.address);
    });

    it('should preserve frozen address state on new wallet', async () => {
      const {
        suite: { token1155 },
        accounts: { aliceWallet, davidWallet, tokenAgent },
        identities: { aliceIdentity },
      } = await loadFixture(deployFullSuite1155Fixture);

      // Freeze alice's address globally
      await token1155.connect(tokenAgent).setAddressFrozen(aliceWallet.address, true);

      // Add davidWallet as management key
      await aliceIdentity
        .connect(aliceWallet)
        .addKey(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [davidWallet.address])), 1, 1);

      await token1155.connect(tokenAgent).recoveryAddress(aliceWallet.address, davidWallet.address, aliceIdentity.address);

      // David should have the frozen address state preserved
      expect(await token1155.isFrozen(davidWallet.address)).to.be.true;
      expect(await token1155.balanceOf(davidWallet.address, 0)).to.equal(1000);
    });
  });

  describe('Owner functions', () => {
    describe('.setName()', () => {
      it('should update name', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(deployer).setName('NewName');
        expect(await token1155.name()).to.equal('NewName');
      });

      it('should revert if not owner', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(token1155.connect(aliceWallet).setName('NewName')).to.be.revertedWith(
          'Ownable: caller is not the owner',
        );
      });

      it('should revert with empty string', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(deployer).setName(''),
        ).to.be.revertedWithCustomError(token1155, 'EmptyString');
      });
    });

    describe('.setSymbol()', () => {
      it('should update symbol', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(deployer).setSymbol('NEW');
        expect(await token1155.symbol()).to.equal('NEW');
      });

      it('should revert if not owner', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(token1155.connect(aliceWallet).setSymbol('NEW')).to.be.revertedWith(
          'Ownable: caller is not the owner',
        );
      });

      it('should revert with empty string', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(deployer).setSymbol(''),
        ).to.be.revertedWithCustomError(token1155, 'EmptyString');
      });
    });

    describe('.setOnchainID()', () => {
      it('should update onchainID', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer, anotherWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(deployer).setOnchainID(anotherWallet.address);
        expect(await token1155.onchainID()).to.equal(anotherWallet.address);
      });

      it('should revert if not owner', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet, anotherWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).setOnchainID(anotherWallet.address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('.setIdentityRegistry()', () => {
      it('should revert if not owner', async () => {
        const {
          suite: { token1155, identityRegistry },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).setIdentityRegistry(identityRegistry.address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('.setTokenURI()', () => {
      it('should set token URI', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await token1155.connect(deployer).setTokenURI(0, 'https://example.com/0.json');
        expect(await token1155.uri(0)).to.equal('https://example.com/0.json');
      });

      it('should revert if not owner', async () => {
        const {
          suite: { token1155 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).setTokenURI(0, 'https://example.com/0.json'),
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(deployer).setTokenURI(99, 'https://example.com/99.json'),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });
    });

    describe('.setTokenCompliance()', () => {
      it('should update compliance for a tokenId', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
          authorities: { trexImplementationAuthority },
        } = await loadFixture(deployFullSuite1155Fixture);

        const newCompliance = await ethers
          .deployContract('ModularComplianceProxy', [trexImplementationAuthority.address], deployer)
          .then(async (proxy) => ethers.getContractAt('ModularCompliance', proxy.address));

        await token1155.connect(deployer).setTokenCompliance(0, newCompliance.address);
        expect(await token1155.tokenCompliance(0)).to.equal(newCompliance.address);
      });

      it('should revert if not owner', async () => {
        const {
          suite: { token1155, compliance0 },
          accounts: { aliceWallet },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(aliceWallet).setTokenCompliance(0, compliance0.address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
      });

      it('should revert with zero address', async () => {
        const {
          suite: { token1155 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(deployer).setTokenCompliance(0, ethers.constants.AddressZero),
        ).to.be.revertedWithCustomError(token1155, 'ZeroAddress');
      });

      it('should revert for non-existent tokenId', async () => {
        const {
          suite: { token1155, compliance0 },
          accounts: { deployer },
        } = await loadFixture(deployFullSuite1155Fixture);

        await expect(
          token1155.connect(deployer).setTokenCompliance(99, compliance0.address),
        ).to.be.revertedWithCustomError(token1155, 'TokenIdDoesNotExist').withArgs(99);
      });

      it('should unbind old compliance before binding new', async () => {
        const {
          suite: { token1155, compliance0 },
          accounts: { deployer },
          authorities: { trexImplementationAuthority },
        } = await loadFixture(deployFullSuite1155Fixture);

        const newCompliance = await ethers
          .deployContract('ModularComplianceProxy', [trexImplementationAuthority.address], deployer)
          .then(async (proxy) => ethers.getContractAt('ModularCompliance', proxy.address));

        // First compliance should be bound
        expect(await compliance0.getTokenBound()).to.equal(token1155.address);

        await token1155.connect(deployer).setTokenCompliance(0, newCompliance.address);

        // Old compliance should be unbound
        expect(await compliance0.getTokenBound()).to.not.equal(token1155.address);
        // New compliance should be bound
        expect(await newCompliance.getTokenBound()).to.equal(token1155.address);
      });
    });
  });

  describe('Cross-tokenId isolation', () => {
    it('compliance state on tokenId 0 should not leak to tokenId 1', async () => {
      const {
        suite: { token1155, compliance0, compliance1 },
      } = await loadFixture(deployFullSuite1155Fixture);

      // The two compliances are separate contract instances
      expect(compliance0.address).to.not.equal(compliance1.address);
      expect(await token1155.tokenCompliance(0)).to.equal(compliance0.address);
      expect(await token1155.tokenCompliance(1)).to.equal(compliance1.address);
    });

    it('total supply is tracked independently per tokenId', async () => {
      const {
        suite: { token1155 },
      } = await loadFixture(deployFullSuite1155Fixture);

      expect(await token1155.totalSupply(0)).to.equal(1500);
      expect(await token1155.totalSupply(1)).to.equal(3000);
    });
  });
});
