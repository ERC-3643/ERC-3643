import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployComplianceFixture } from '../fixtures/deploy-compliance.fixture';

async function deployComplianceWithTestModule() {
  const context = await loadFixture(deployComplianceFixture);
  const { compliance } = context.suite;

  const module = await ethers.deployContract('TestModule');
  const proxy = await ethers.deployContract('ModuleProxy', [module.target, module.interface.encodeFunctionData('initialize')]);
  const testModule = await ethers.getContractAt('TestModule', proxy.target);
  await compliance.addModule(testModule.target);

  const contract = await ethers.deployContract('MockContract');
  await compliance.bindToken(contract.target);
  await contract.setCompliance(compliance.target);

  return { ...context, suite: { ...context.suite, testModule, mock: contract } };
}

describe('UtilityChecker.testTransferDetails', () => {
  it('should return pass for single module', async () => {
    const context = await loadFixture(deployComplianceWithTestModule);

    const utilityChecker = await ethers.deployContract('UtilityChecker');
    const results = await utilityChecker.testTransferDetails(
      context.suite.mock.target,
      context.accounts.aliceWallet,
      context.accounts.bobWallet,
      100,
    );
    expect(results.length).to.equal(1);
    expect(results[0][0]).to.equal('TestModule');
    expect(results[0][1]).to.equal(true);
  });

  it('should return no pass for one of multiple modules', async () => {
    const context = await loadFixture(deployComplianceWithTestModule);

    // Deploy second module with proxy
    const testModule2Implementation = await ethers.deployContract('TestModule');
    const testModule2Proxy = await ethers.deployContract('ModuleProxy', [
      testModule2Implementation.target,
      testModule2Implementation.interface.encodeFunctionData('initialize'),
    ]);
    const testModule2 = await ethers.getContractAt('TestModule', testModule2Proxy.target);

    // Add the proxy address to compliance, not the implementation
    await context.suite.compliance.addModule(testModule2.target);

    // block the second test module to show 2 different outputs
    await context.suite.compliance.callModuleFunction(
      new ethers.Interface(['function blockModule(bool _blocked)']).encodeFunctionData('blockModule', [true]),
      testModule2.target,
    );

    const utilityChecker = await ethers.deployContract('UtilityChecker');
    const results = await utilityChecker.testTransferDetails(
      context.suite.mock.target,
      context.accounts.aliceWallet,
      context.accounts.bobWallet,
      100,
    );
    expect(results.length).to.equal(2);
    expect(results[0][0]).to.equal('TestModule');
    expect(results[0][1]).to.equal(true);
    expect(results[1][0]).to.equal('TestModule');
    expect(results[1][1]).to.equal(false);
  });

  it('should return pass for multiple modules', async () => {
    const context = await loadFixture(deployComplianceWithTestModule);

    // Deploy second module with proxy
    const testModule2Implementation = await ethers.deployContract('TestModule');
    const testModule2Proxy = await ethers.deployContract('ModuleProxy', [
      testModule2Implementation.target,
      testModule2Implementation.interface.encodeFunctionData('initialize'),
    ]);
    const testModule2 = await ethers.getContractAt('TestModule', testModule2Proxy.target);

    // Add the proxy address to compliance, not the implementation
    await context.suite.compliance.addModule(testModule2.target);

    const utilityChecker = await ethers.deployContract('UtilityChecker');
    const results = await utilityChecker.testTransferDetails(
      context.suite.mock.target,
      context.accounts.aliceWallet,
      context.accounts.bobWallet,
      100,
    );
    expect(results.length).to.equal(2);
    expect(results[0][0]).to.equal('TestModule');
    expect(results[0][1]).to.equal(true);
    expect(results[1][0]).to.equal('TestModule');
    expect(results[1][1]).to.equal(true);
  });
});
