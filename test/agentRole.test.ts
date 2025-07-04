import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

async function deployAgentFixture() {
  const [ownerWallet, aliceWallet, bobWallet] = await ethers.getSigners();

  const agentRole = await ethers.deployContract('AgentRole');

  return {
    accounts: {
      ownerWallet,
      aliceWallet,
      bobWallet,
    },
    contracts: {
      agentRole,
    },
  };
}

describe('AgentRole', () => {
  describe('.addAgent', () => {
    describe('when the sender is not the owner', () => {
      it('should reverts', async () => {
        const {
          accounts: { aliceWallet, bobWallet },
          contracts: { agentRole },
        } = await loadFixture(deployAgentFixture);

        await expect(agentRole.connect(bobWallet).addAgent(aliceWallet.address)).to.be.revertedWithCustomError(
          agentRole,
          'OwnableUnauthorizedAccount',
        );
      });
    });

    describe('when the sender is the owner', () => {
      describe('when address to add is the zero address', () => {
        it('should reverts', async () => {
          const {
            accounts: { ownerWallet },
            contracts: { agentRole },
          } = await loadFixture(deployAgentFixture);

          await expect(agentRole.connect(ownerWallet).addAgent(ethers.ZeroAddress)).to.be.revertedWithCustomError(agentRole, 'ZeroAddress');
        });
      });

      describe('when address to add is a valid address', () => {
        describe('when address to add is already an agent', () => {
          it('should reverts', async () => {
            const {
              accounts: { ownerWallet, aliceWallet },
              contracts: { agentRole },
            } = await loadFixture(deployAgentFixture);

            await agentRole.connect(ownerWallet).addAgent(aliceWallet.address);
            await expect(agentRole.connect(ownerWallet).addAgent(aliceWallet.address)).to.be.revertedWithCustomError(
              agentRole,
              'AccountAlreadyHasRole',
            );
          });
        });

        describe('when address to add is not an agent address', () => {
          it('should add the agent', async () => {
            const {
              accounts: { ownerWallet, aliceWallet },
              contracts: { agentRole },
            } = await loadFixture(deployAgentFixture);

            const tx = await agentRole.connect(ownerWallet).addAgent(aliceWallet.address);
            await expect(tx).to.emit(agentRole, 'AgentAdded').withArgs(aliceWallet.address);
            expect(await agentRole.isAgent(aliceWallet.address)).to.be.true;
          });
        });
      });
    });
  });

  describe('.removeAgent', () => {
    describe('when the sender is not the owner', () => {
      it('should reverts', async () => {
        const {
          accounts: { aliceWallet, bobWallet },
          contracts: { agentRole },
        } = await loadFixture(deployAgentFixture);

        await expect(agentRole.connect(bobWallet).removeAgent(aliceWallet.address)).to.be.revertedWithCustomError(
          agentRole,
          'OwnableUnauthorizedAccount',
        );
      });
    });

    describe('when the sender is the owner', () => {
      describe('when address to add is the zero address', () => {
        it('should reverts', async () => {
          const {
            accounts: { ownerWallet },
            contracts: { agentRole },
          } = await loadFixture(deployAgentFixture);

          await expect(agentRole.connect(ownerWallet).removeAgent(ethers.ZeroAddress)).to.be.revertedWithCustomError(agentRole, 'ZeroAddress');
        });
      });

      describe('when address to add is a valid address', () => {
        describe('when address to add is not an agent', () => {
          it('should reverts', async () => {
            const {
              accounts: { ownerWallet, aliceWallet },
              contracts: { agentRole },
            } = await loadFixture(deployAgentFixture);

            await expect(agentRole.connect(ownerWallet).removeAgent(aliceWallet.address)).to.be.revertedWithCustomError(
              agentRole,
              'AccountDoesNotHaveRole',
            );
          });
        });

        describe('when address to add is an agent address', () => {
          it('should remove the agent', async () => {
            const {
              accounts: { ownerWallet, aliceWallet },
              contracts: { agentRole },
            } = await loadFixture(deployAgentFixture);

            await agentRole.connect(ownerWallet).addAgent(aliceWallet.address);
            const tx = await agentRole.connect(ownerWallet).removeAgent(aliceWallet.address);
            await expect(tx).to.emit(agentRole, 'AgentRemoved').withArgs(aliceWallet.address);
            expect(await agentRole.isAgent(aliceWallet.address)).to.be.false;
          });
        });
      });
    });
  });
});

describe('OwnableOnceNext2StepUpgradeable', () => {
  describe('when first deploy', () => {
    it('should set owner to caller', async () => {
      const [deployer] = await ethers.getSigners();

      const modularCompliance = await ethers.deployContract('ModularCompliance');
      await modularCompliance.init();

      expect(await modularCompliance.owner()).to.equal(deployer.address);
    });
  });

  describe('when set first owner', () => {
    it('should set next owner to caller', async () => {
      const [deployer, aliceWallet] = await ethers.getSigners();

      const modularCompliance = await ethers.deployContract('ModularCompliance');
      await modularCompliance.init();

      await modularCompliance.connect(deployer).transferOwnership(aliceWallet.address);

      expect(await modularCompliance.owner()).to.equal(aliceWallet.address);
    });
  });

  describe('when next owner is set', () => {
    it('should set owner to next owner in 2 steps', async () => {
      const [deployer, aliceWallet, bobWallet] = await ethers.getSigners();

      const modularCompliance = await ethers.deployContract('ModularCompliance');
      await modularCompliance.init();

      await modularCompliance.connect(deployer).transferOwnership(aliceWallet.address);

      let tx = await modularCompliance.connect(aliceWallet).transferOwnership(bobWallet.address);
      await expect(tx).to.emit(modularCompliance, 'OwnershipTransferStarted').withArgs(aliceWallet.address, bobWallet.address);

      tx = await modularCompliance.connect(bobWallet).acceptOwnership();
      await expect(tx).to.emit(modularCompliance, 'OwnershipTransferred').withArgs(aliceWallet.address, bobWallet.address);

      expect(await modularCompliance.owner()).to.equal(bobWallet.address);
    });
  });
});
