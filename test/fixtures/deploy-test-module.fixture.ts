import { ethers } from 'hardhat';
import { deployComplianceFixture } from './deploy-compliance.fixture';

// eslint-disable-next-line import/prefer-default-export
export async function deployTestModuleFixture() {
  // Use existing compliance fixture
  const { accounts, suite } = await deployComplianceFixture();
  const { compliance } = suite;

  // Deploy TestModule
  const testModuleImplementation = await ethers.deployContract('TestModule');
  const testModuleProxy = await ethers.deployContract('@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy', [
    testModuleImplementation.target,
    testModuleImplementation.interface.encodeFunctionData('initialize'),
  ]);
  const testModule = await ethers.getContractAt('TestModule', testModuleProxy.target);

  // Add the module to compliance
  await compliance.addModule(testModule.target);

  return {
    accounts,
    suite: {
      compliance,
      testModule,
    },
  };
}
