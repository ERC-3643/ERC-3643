import { ethers } from 'hardhat';

// eslint-disable-next-line import/prefer-default-export
export async function deployTestModuleFixture() {
  const [deployer, aliceWallet, bobWallet, anotherWallet] = await ethers.getSigners();

  // Deploy ModularCompliance
  const compliance = await ethers.deployContract('ModularCompliance');
  await compliance.init();

  // Deploy TestModule
  const testModule = await ethers.deployContract('TestModule');
  await testModule.initialize();

  // Add the module to compliance
  await compliance.addModule(testModule.target);

  return {
    accounts: {
      deployer,
      aliceWallet,
      bobWallet,
      anotherWallet,
    },
    suite: {
      compliance,
      testModule,
    },
  };
}
