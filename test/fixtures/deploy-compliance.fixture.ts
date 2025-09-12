import { ethers } from 'hardhat';

// eslint-disable-next-line import/prefer-default-export
export async function deployComplianceFixture() {
  const [deployer, aliceWallet, bobWallet, anotherWallet] = await ethers.getSigners();

  const complianceImplementation = await ethers.deployContract('ModularCompliance');
  const complianceProxy = await ethers.deployContract('@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy', [
    complianceImplementation.target,
    complianceImplementation.interface.encodeFunctionData('init'),
  ]);

  const compliance = await ethers.getContractAt('ModularCompliance', complianceProxy.target);

  return {
    accounts: {
      deployer,
      aliceWallet,
      bobWallet,
      anotherWallet,
    },
    suite: {
      compliance,
    },
  };
}
