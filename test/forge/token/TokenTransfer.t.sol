// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IIdentity } from "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import { IdentityProxy } from "@onchain-id/solidity/contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "@onchain-id/solidity/contracts/proxy/ImplementationAuthority.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { TestModule } from "contracts/_testContracts/TestModule.sol";
import { ModularCompliance } from "contracts/compliance/modular/ModularCompliance.sol";
import { ModuleProxy } from "contracts/compliance/modular/modules/ModuleProxy.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { IdentityRegistry } from "contracts/registry/implementation/IdentityRegistry.sol";
import {
    AgentNotAuthorized,
    AmountAboveFrozenTokens,
    CallerDoesNotHaveAgentRole,
    ERC20InsufficientBalance,
    EnforcedPause,
    FrozenWallet,
    TransferNotPossible
} from "contracts/token/Token.sol";
import { Token } from "contracts/token/Token.sol";
import { TokenRoles } from "contracts/token/TokenStructs.sol";
import { TREXFactorySetup } from "test/forge/helpers/TREXFactorySetup.sol";

contract TokenTransferTest is TREXFactorySetup {

    // Event declarations for expectEmit
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokensFrozen(address indexed _userAddress, uint256 _amount);
    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);
    event DefaultAllowance(address indexed _target, bool _status);
    event DefaultAllowanceEnabled(address indexed _user);
    event DefaultAllowanceDisabled(address indexed _user);

    // Token suite deployed in setUp()
    address public tokenAddress;
    Token public token;
    IdentityRegistry public identityRegistry;
    IIdentity public aliceIdentity;
    IIdentity public bobIdentity;

    // Additional test addresses
    address public tokenAgent = makeAddr("tokenAgent");

    function setUp() public override {
        super.setUp();

        // Deploy token suite
        ITREXFactory.TokenDetails memory tokenDetails = ITREXFactory.TokenDetails({
            owner: deployer,
            name: "TREX DINO",
            symbol: "TREXD",
            decimals: 0,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });
        ITREXFactory.ClaimDetails memory claimDetails = ITREXFactory.ClaimDetails({
            claimTopics: new uint256[](0), issuers: new address[](0), issuerClaims: new uint256[][](0)
        });

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        tokenAddress = trexFactory.getToken("salt");
        token = Token(tokenAddress);

        // Get IdentityRegistry
        IERC3643IdentityRegistry ir = token.identityRegistry();
        identityRegistry = IdentityRegistry(address(ir));

        // Create identities
        ImplementationAuthority identityImplementationAuthority =
            ImplementationAuthority(onchainidSetup.idFactory.implementationAuthority());
        aliceIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), alice)));
        bobIdentity = IIdentity(address(new IdentityProxy(address(identityImplementationAuthority), bob)));

        // Add tokenAgent as an agent
        vm.prank(deployer);
        token.addAgent(tokenAgent);

        // Add tokenAgent as an agent to IdentityRegistry
        vm.prank(deployer);
        identityRegistry.addAgent(tokenAgent);

        // Register alice and bob in IdentityRegistry
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(alice, aliceIdentity, 42);
        vm.prank(tokenAgent);
        identityRegistry.registerIdentity(bob, bobIdentity, 666);

        // Mint tokens alice=1000, bob=500)
        vm.prank(tokenAgent);
        token.mint(alice, 1000);
        vm.prank(tokenAgent);
        token.mint(bob, 500);

        // Unpause token
        vm.prank(tokenAgent);
        token.unpause();
    }

    /// @notice Helper to deploy TestModule + ModularCompliance setup for compliance tests
    function _deployComplianceSetup() internal returns (ModularCompliance, TestModule) {
        // Deploy ModularCompliance
        ModularCompliance complianceImplementation = new ModularCompliance();
        bytes memory complianceInitData = abi.encodeWithSelector(ModularCompliance.init.selector);
        ERC1967Proxy complianceProxy = new ERC1967Proxy(address(complianceImplementation), complianceInitData);
        ModularCompliance compliance = ModularCompliance(address(complianceProxy));

        // Transfer ownership to deployer
        vm.prank(address(this));
        compliance.transferOwnership(deployer);

        // Deploy TestModule
        TestModule testModuleImplementation = new TestModule();
        bytes memory moduleInitData = abi.encodeWithSelector(TestModule.initialize.selector);
        ModuleProxy testModuleProxy = new ModuleProxy(address(testModuleImplementation), moduleInitData);
        TestModule testModule = TestModule(address(testModuleProxy));

        // Add module to compliance
        vm.prank(deployer);
        compliance.addModule(address(testModule));

        return (compliance, testModule);
    }

    // ============ approve() Tests ============

    /// @notice Should approve a contract to spend a certain amount of tokens
    function test_approve_Success() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(token));
        emit Approval(alice, another, 100);
        token.approve(another, 100);

        assertEq(token.allowance(alice, another), 100);
    }

    // ============ increaseAllowance() Tests ============

    /// @notice Should increase the allowance of a contract to spend a certain amount of tokens
    function test_increaseAllowance_Success() public {
        vm.prank(alice);
        token.approve(another, 100);

        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(token));
        emit Approval(alice, another, 200);
        token.increaseAllowance(another, 100);

        assertEq(token.allowance(alice, another), 200);
    }

    // ============ decreaseAllowance() Tests ============

    /// @notice Should decrease the allowance of a contract to spend a certain amount of tokens
    function test_decreaseAllowance_Success() public {
        vm.prank(alice);
        token.approve(another, 150);

        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(token));
        emit Approval(alice, another, 50);
        token.decreaseAllowance(another, 100);

        assertEq(token.allowance(alice, another), 50);
    }

    // ============ transfer() Tests ============

    /// @notice Should revert when token is paused
    function test_transfer_RevertWhen_Paused() public {
        vm.prank(tokenAgent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(EnforcedPause.selector);
        token.transfer(bob, 100);
    }

    /// @notice Should revert when recipient balance is frozen
    function test_transfer_RevertWhen_RecipientFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);

        vm.prank(alice);
        vm.expectRevert(FrozenWallet.selector);
        token.transfer(bob, 100);
    }

    /// @notice Should revert when sender balance is frozen
    function test_transfer_RevertWhen_SenderFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(alice, true);

        vm.prank(alice);
        vm.expectRevert(FrozenWallet.selector);
        token.transfer(bob, 100);
    }

    /// @notice Should revert when sender has not enough balance
    function test_transfer_RevertWhen_InsufficientBalance() public {
        uint256 balance = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, balance, balance + 1000));
        token.transfer(bob, balance + 1000);
    }

    /// @notice Should revert when sender has not enough balance unfrozen
    function test_transfer_RevertWhen_InsufficientUnfrozenBalance() public {
        uint256 balance = token.balanceOf(alice);
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, balance - 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, 100, balance));
        token.transfer(bob, balance);
    }

    /// @notice Should revert when recipient identity is not verified
    function test_transfer_RevertWhen_RecipientNotVerified() public {
        vm.prank(alice);
        vm.expectRevert(TransferNotPossible.selector);
        token.transfer(another, 100);
    }

    /// @notice Should revert when transfer breaks compliance rules
    function test_transfer_RevertWhen_ComplianceBreaks() public {
        (ModularCompliance compliance, TestModule testModule) = _deployComplianceSetup();

        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Block transfers in module
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule));

        vm.prank(alice);
        vm.expectRevert(TransferNotPossible.selector);
        token.transfer(bob, 100);
    }

    /// @notice Should transfer tokens when transfer is compliant
    function test_transfer_Success() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        token.transfer(bob, 100);
    }

    // ============ batchTransfer() Tests ============

    /// @notice Should transfer tokens
    function test_batchTransfer_Success() public {
        address[] memory toList = new address[](2);
        toList[0] = bob;
        toList[1] = bob;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(alice);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 200);
        token.batchTransfer(toList, amounts);
    }

    // ============ transferFrom() Tests ============

    /// @notice Should revert when token is paused
    function test_transferFrom_RevertWhen_Paused() public {
        vm.prank(tokenAgent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(EnforcedPause.selector);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should revert when sender address is frozen
    function test_transferFrom_RevertWhen_SenderFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(alice, true);

        vm.prank(alice);
        vm.expectRevert(FrozenWallet.selector);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should revert when recipient address is frozen
    function test_transferFrom_RevertWhen_RecipientFrozen() public {
        vm.prank(tokenAgent);
        token.setAddressFrozen(bob, true);

        vm.prank(alice);
        vm.expectRevert(FrozenWallet.selector);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should revert when sender has not enough balance
    function test_transferFrom_RevertWhen_InsufficientBalance() public {
        uint256 balance = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, balance, balance + 1000));
        token.transferFrom(alice, bob, balance + 1000);
    }

    /// @notice Should revert when sender has not enough balance unfrozen
    function test_transferFrom_RevertWhen_InsufficientUnfrozenBalance() public {
        uint256 balance = token.balanceOf(alice);
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, balance - 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, 100, balance));
        token.transferFrom(alice, bob, balance);
    }

    /// @notice Should revert when recipient identity is not verified
    function test_transferFrom_RevertWhen_RecipientNotVerified() public {
        vm.prank(alice);
        vm.expectRevert(TransferNotPossible.selector);
        token.transferFrom(alice, another, 100);
    }

    /// @notice Should revert when transfer breaks compliance rules
    function test_transferFrom_RevertWhen_ComplianceBreaks() public {
        (ModularCompliance compliance, TestModule testModule) = _deployComplianceSetup();

        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Block transfers in module
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule));

        vm.prank(alice);
        vm.expectRevert(TransferNotPossible.selector);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should transfer tokens and reduce allowance of transferred value
    function test_transferFrom_Success() public {
        vm.prank(alice);
        token.approve(another, 100);

        vm.prank(another);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        token.transferFrom(alice, bob, 100);

        assertEq(token.allowance(alice, another), 0);
    }

    // ============ forcedTransfer() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_forcedTransfer_RevertWhen_NotAgent() public {
        vm.prank(alice);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.forcedTransfer(alice, bob, 100);
    }

    /// @notice Should revert when agent permission is restricted
    function test_forcedTransfer_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: true,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "forceTransfer disabled"));
        token.forcedTransfer(alice, bob, 100);
    }

    /// @notice Should revert when source wallet has not enough balance
    function test_forcedTransfer_RevertWhen_InsufficientBalance() public {
        uint256 balance = token.balanceOf(alice);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, balance, balance + 1000));
        token.forcedTransfer(alice, bob, balance + 1000);
    }

    /// @notice Should revert when recipient identity is not verified
    function test_forcedTransfer_RevertWhen_RecipientNotVerified() public {
        vm.prank(tokenAgent);
        vm.expectRevert(TransferNotPossible.selector);
        token.forcedTransfer(alice, another, 100);
    }

    /// @notice Should still transfer tokens when transfer breaks compliance rules
    function test_forcedTransfer_Success_WhenComplianceBreaks() public {
        (ModularCompliance compliance, TestModule testModule) = _deployComplianceSetup();

        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Block transfers in module
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule));

        vm.prank(tokenAgent);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        token.forcedTransfer(alice, bob, 100);
    }

    /// @notice Should unfreeze tokens when amount is greater than unfrozen balance
    function test_forcedTransfer_Success_UnfreezesTokens() public {
        uint256 balance = token.balanceOf(alice);
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, balance - 100);

        uint256 transferAmount = balance - 50;
        uint256 unfreezeAmount = balance - 150;
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, transferAmount);
        token.forcedTransfer(alice, bob, transferAmount);

        // Check unfrozen tokens separately (event order may vary)
        assertEq(token.getFrozenTokens(alice), 50);
    }

    // ============ mint() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_mint_RevertWhen_NotAgent() public {
        vm.prank(alice);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.mint(alice, 100);
    }

    /// @notice Should revert when agent permission is restricted
    function test_mint_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: true,
            disableBurn: false,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "mint disabled"));
        token.mint(alice, 100);
    }

    /// @notice Should revert when recipient identity is not verified
    function test_mint_RevertWhen_RecipientNotVerified() public {
        vm.prank(tokenAgent);
        vm.expectRevert();
        token.mint(another, 100);
    }

    /// @notice Should revert when the mint breaks compliance rules
    function test_mint_RevertWhen_ComplianceBreaks() public {
        (ModularCompliance compliance, TestModule testModule) = _deployComplianceSetup();

        vm.prank(deployer);
        token.setCompliance(address(compliance));

        // Block transfers in module
        bytes memory blockModuleCall = abi.encodeWithSignature("blockModule(bool)", true);
        vm.prank(deployer);
        compliance.callModuleFunction(blockModuleCall, address(testModule));

        vm.prank(tokenAgent);
        vm.expectRevert();
        token.mint(alice, 100);
    }

    // ============ burn() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_burn_RevertWhen_NotAgent() public {
        vm.prank(alice);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.burn(alice, 100);
    }

    /// @notice Should revert when agent permission is restricted
    function test_burn_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: true,
            disablePartialFreeze: false,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "burn disabled"));
        token.burn(alice, 100);
    }

    /// @notice Should revert when source wallet has not enough balance
    function test_burn_RevertWhen_InsufficientBalance() public {
        uint256 balance = token.balanceOf(alice);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, alice, balance, balance + 1000));
        token.burn(alice, balance + 1000);
    }

    /// @notice Should burn and decrease frozen balance when amount to burn is greater than unfrozen balance
    function test_burn_Success_DecreasesFrozenBalance() public {
        uint256 balance = token.balanceOf(alice);
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, balance - 100);

        uint256 burnAmount = balance - 50;
        vm.prank(tokenAgent);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, address(0), burnAmount);
        token.burn(alice, burnAmount);

        // Check frozen tokens (event order may vary)
        assertEq(token.getFrozenTokens(alice), 50);
    }

    // ============ freezePartialTokens() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_freezePartialTokens_RevertWhen_NotAgent() public {
        vm.prank(alice);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.freezePartialTokens(alice, 100);
    }

    /// @notice Should revert when agent permission is restricted
    function test_freezePartialTokens_RevertWhen_AgentRestricted() public {
        TokenRoles memory restrictions = TokenRoles({
            disableMint: false,
            disableBurn: false,
            disablePartialFreeze: true,
            disableAddressFreeze: false,
            disableRecovery: false,
            disableForceTransfer: false,
            disablePause: false
        });

        vm.prank(deployer);
        token.setAgentRestrictions(tokenAgent, restrictions);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AgentNotAuthorized.selector, tokenAgent, "partial freeze disabled"));
        token.freezePartialTokens(alice, 100);
    }

    // ============ unfreezePartialTokens() Tests ============

    /// @notice Should revert when sender is not an agent
    function test_unfreezePartialTokens_RevertWhen_NotAgent() public {
        vm.prank(alice);
        vm.expectRevert(CallerDoesNotHaveAgentRole.selector);
        token.unfreezePartialTokens(alice, 100);
    }

    /// @notice Should revert when amount exceeds frozen tokens
    function test_unfreezePartialTokens_RevertWhen_AmountExceedsFrozen() public {
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, 200);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(AmountAboveFrozenTokens.selector, 5000, 200));
        token.unfreezePartialTokens(alice, 5000);
    }

    /// @notice Should unfreeze when freeze amount does not exceed the balance
    function test_unfreezePartialTokens_Success() public {
        vm.prank(tokenAgent);
        token.freezePartialTokens(alice, 200);

        vm.prank(tokenAgent);
        vm.expectEmit(true, false, false, false, address(token));
        emit TokensUnfrozen(alice, 100);
        token.unfreezePartialTokens(alice, 100);
    }

    // ============ setAllowanceForAll() / Default Allowance Tests ============

    /// @notice Should only allow the owner to set default allowances
    function test_setAllowanceForAll_OnlyOwner() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.setAllowanceForAll(true, targets);

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);

        // Verify default allowance is set
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    /// @notice Should revert if default allowance is already set for a target
    function test_setAllowanceForAll_RevertWhen_AlreadySet() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("DefaultAllowanceAlreadySet(address)")), bob));
        token.setAllowanceForAll(true, targets);
    }

    /// @notice Should allow transfer without explicit allowance for addresses with default allowance
    function test_setAllowanceForAll_AllowsTransferWithoutAllowance() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(alice, bob, 100);

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);

        vm.prank(bob);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should allow users to opt out of default allowance
    function test_setAllowanceForAll_OptOut() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);

        vm.prank(bob);
        token.transferFrom(alice, bob, 100);

        vm.prank(alice);
        token.disableDefaultAllowance();

        // Verify default allowance is disabled
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 100);

        vm.prank(alice);
        token.enableDefaultAllowance();

        // Verify default allowance is re-enabled
        vm.prank(bob);
        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(alice, bob, 100);
        token.transferFrom(alice, bob, 100);
    }

    /// @notice Should revert if a user tries to disable an already disabled default allowance
    function test_disableDefaultAllowance_RevertWhen_AlreadyDisabled() public {
        vm.prank(alice);
        token.disableDefaultAllowance();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("DefaultAllowanceAlreadyDisabled(address)")), alice));
        token.disableDefaultAllowance();
    }

    /// @notice Should revert if a user tries to enable an already enabled default allowance
    function test_enableDefaultAllowance_RevertWhen_AlreadyEnabled() public {
        vm.prank(alice);
        token.disableDefaultAllowance();
        vm.prank(alice);
        token.enableDefaultAllowance();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("DefaultAllowanceAlreadyEnabled(address)")), alice));
        token.enableDefaultAllowance();
    }

    /// @notice Should return max uint256 as allowance for addresses with default allowance when user has not opted out
    function test_allowance_ReturnsMaxUint256_WhenDefaultAllowanceSet() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);

        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    /// @notice Should return actual allowance when user has opted out of default allowance
    function test_allowance_ReturnsActual_WhenOptedOut() public {
        address[] memory targets = new address[](1);
        targets[0] = bob;

        vm.prank(deployer);
        token.setAllowanceForAll(true, targets);
        vm.prank(alice);
        token.disableDefaultAllowance();

        assertEq(token.allowance(alice, bob), 0);
    }

}
