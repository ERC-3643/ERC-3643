import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Interface } from 'ethers';
import { deployTestModuleFixture } from '../fixtures/deploy-test-module.fixture';

describe('TestModule Multicall', () => {
  it('should execute multiple doSomething calls in a single transaction', async () => {
    const {
      suite: { compliance, testModule },
      accounts: { deployer },
    } = await loadFixture(deployTestModuleFixture);

    const doSomething42Data = new Interface(['function doSomething(uint _value)']).encodeFunctionData('doSomething', [42]);
    const doSomething43Data = new Interface(['function doSomething(uint _value)']).encodeFunctionData('doSomething', [43]);

    const tx = await compliance
      .connect(deployer)
      .callModuleFunction(
        new Interface(['function multicall(bytes[] calldata data)']).encodeFunctionData('multicall', [[doSomething42Data, doSomething43Data]]),
        testModule.target,
      );

    await expect(tx).to.not.be.reverted;

    // Verify state changes - the last call should overwrite the first one
    expect(await testModule.getComplianceData(compliance.target)).to.equal(43);
  });

  it('should execute multiple blockModule calls in a single transaction', async () => {
    const {
      suite: { compliance, testModule },
      accounts: { deployer },
    } = await loadFixture(deployTestModuleFixture);

    const blockModuleTrueData = new Interface(['function blockModule(bool _blocked)']).encodeFunctionData('blockModule', [true]);
    const blockModuleFalseData = new Interface(['function blockModule(bool _blocked)']).encodeFunctionData('blockModule', [false]);

    const tx = await compliance
      .connect(deployer)
      .callModuleFunction(
        new Interface(['function multicall(bytes[] calldata data)']).encodeFunctionData('multicall', [[blockModuleTrueData, blockModuleFalseData]]),
        testModule.target,
      );

    await expect(tx).to.not.be.reverted;

    // Verify state changes - the last call should overwrite the first one
    expect(await testModule.getBlockedTransfers(compliance.target)).to.equal(false);
  });

  it('should execute mixed doSomething and blockModule calls in a single transaction', async () => {
    const {
      suite: { compliance, testModule },
      accounts: { deployer },
    } = await loadFixture(deployTestModuleFixture);

    const doSomething100Data = new Interface(['function doSomething(uint _value)']).encodeFunctionData('doSomething', [100]);
    const blockModuleTrueData = new Interface(['function blockModule(bool _blocked)']).encodeFunctionData('blockModule', [true]);
    const doSomething200Data = new Interface(['function doSomething(uint _value)']).encodeFunctionData('doSomething', [200]);

    const tx = await compliance
      .connect(deployer)
      .callModuleFunction(
        new Interface(['function multicall(bytes[] calldata data)']).encodeFunctionData('multicall', [
          [doSomething100Data, blockModuleTrueData, doSomething200Data],
        ]),
        testModule.target,
      );

    await expect(tx).to.not.be.reverted;

    // Verify state changes - both should be set to the last values
    expect(await testModule.getComplianceData(compliance.target)).to.equal(200);
    expect(await testModule.getBlockedTransfers(compliance.target)).to.equal(true);
  });

  it('should revert when calling multicall directly on module (not from compliance)', async () => {
    const {
      suite: { testModule },
      accounts: { deployer },
    } = await loadFixture(deployTestModuleFixture);

    const doSomething42Data = new Interface(['function doSomething(uint _value)']).encodeFunctionData('doSomething', [42]);

    await expect(testModule.connect(deployer).multicall([doSomething42Data])).to.be.revertedWithCustomError(testModule, 'OnlyBoundComplianceCanCall');
  });
});
