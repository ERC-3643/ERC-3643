// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TestERC20 } from "contracts/_testContracts/TestERC20.sol";
import { ArraySizeLimited } from "contracts/errors/CommonErrors.sol";
import { ZeroAddress } from "contracts/errors/InvalidArgumentErrors.sol";
import { SenderIsNotAdmin } from "contracts/errors/RoleErrors.sol";
import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { ITREXGateway } from "contracts/factory/ITREXGateway.sol";
import {
    DeployerAdded,
    DeployerRemoved,
    DeploymentFeeEnabled,
    DeploymentFeeSet,
    FactorySet,
    FeeDiscountApplied,
    GatewaySuiteDeploymentProcessed,
    PublicDeploymentStatusSet
} from "contracts/factory/ITREXGateway.sol";
import { TREXFactory } from "contracts/factory/TREXFactory.sol";
import { TREXGateway } from "contracts/factory/TREXGateway.sol";
import {
    BatchMaxLengthExceeded,
    DeployerAlreadyExists,
    DeployerDoesNotExist,
    DeploymentFeesAlreadyDisabled,
    DeploymentFeesAlreadyEnabled,
    DiscountOutOfRange,
    PublicCannotDeployOnBehalf,
    PublicDeploymentAlreadyDisabled,
    PublicDeploymentAlreadyEnabled,
    PublicDeploymentsNotAllowed
} from "contracts/factory/TREXGateway.sol";
import { InterfaceIdCalculator } from "contracts/utils/InterfaceIdCalculator.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract TREXGatewayTest is TREXFactorySetup {

    TREXGateway public gateway;
    address public tokenAgent = makeAddr("tokenAgent");

    /// @notice Helper to create empty token details
    function _createEmptyTokenDetails() internal view returns (ITREXFactory.TokenDetails memory) {
        return ITREXFactory.TokenDetails({
            owner: deployer,
            name: "Token name",
            symbol: "SYM",
            decimals: 8,
            irs: address(0),
            ONCHAINID: address(0),
            irAgents: new address[](0),
            tokenAgents: new address[](0),
            complianceModules: new address[](0),
            complianceSettings: new bytes[](0)
        });
    }

    /// @notice Helper to create empty claim details
    function _createEmptyClaimDetails() internal pure returns (ITREXFactory.ClaimDetails memory) {
        return ITREXFactory.ClaimDetails({
            claimTopics: new uint256[](0), issuers: new address[](0), issuerClaims: new uint256[][](0)
        });
    }

    /// @notice Helper to deploy gateway and transfer ownership to deployer
    function _deployGateway(address factory, bool publicDeploymentStatus) internal returns (TREXGateway) {
        TREXGateway gateway_ = new TREXGateway(factory, publicDeploymentStatus);
        // Transfer ownership to deployer
        // Test contract is the initial owner so we transfer ownershhip to deployer
        gateway_.transferOwnership(deployer);
        return gateway_;
    }

    // ============================================
    // .setFactory Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_setFactory_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        gateway.setFactory(address(trexFactory));
    }

    /// @notice Should revert when factory address is zero
    function test_setFactory_RevertWhen_FactoryAddressIsZero() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        gateway.setFactory(address(0));
    }

    /// @notice Should set factory when called by owner
    function test_setFactory_Success() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertEq(gateway.getFactory(), address(0));

        vm.expectEmit(true, false, false, false, address(gateway));
        emit FactorySet(address(trexFactory));
        vm.prank(deployer);
        gateway.setFactory(address(trexFactory));

        assertEq(gateway.getFactory(), address(trexFactory));
    }

    // ============================================
    // .setPublicDeploymentStatus Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_setPublicDeploymentStatus_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        gateway.setPublicDeploymentStatus(true);
    }

    /// @notice Should revert when status doesn't change
    function test_setPublicDeploymentStatus_RevertWhen_StatusDoesntChange() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(PublicDeploymentAlreadyDisabled.selector);
        gateway.setPublicDeploymentStatus(false);

        vm.prank(deployer);
        gateway.setPublicDeploymentStatus(true);

        vm.prank(deployer);
        vm.expectRevert(PublicDeploymentAlreadyEnabled.selector);
        gateway.setPublicDeploymentStatus(true);
    }

    /// @notice Should set new status when called by owner
    function test_setPublicDeploymentStatus_Success() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertEq(gateway.getPublicDeploymentStatus(), false);

        vm.expectEmit(true, false, false, false, address(gateway));
        emit PublicDeploymentStatusSet(true);
        vm.prank(deployer);
        gateway.setPublicDeploymentStatus(true);

        assertEq(gateway.getPublicDeploymentStatus(), true);
    }

    // ============================================
    // .transferFactoryOwnership Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_transferFactoryOwnership_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        gateway.transferFactoryOwnership(another);
    }

    /// @notice Should transfer factory ownership when called by owner
    function test_transferFactoryOwnership_Success() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertEq(trexFactory.owner(), address(gateway));

        vm.prank(deployer);
        gateway.transferFactoryOwnership(alice);

        assertEq(trexFactory.owner(), alice);
    }

    // ============================================
    // .enableDeploymentFee Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_enableDeploymentFee_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        gateway.enableDeploymentFee(true);
    }

    /// @notice Should revert when status doesn't change
    function test_enableDeploymentFee_RevertWhen_StatusDoesntChange() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(DeploymentFeesAlreadyDisabled.selector);
        gateway.enableDeploymentFee(false);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(deployer);
        vm.expectRevert(DeploymentFeesAlreadyEnabled.selector);
        gateway.enableDeploymentFee(true);
    }

    /// @notice Should enable deployment fee when called by owner
    function test_enableDeploymentFee_Success() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        // Initially disabled
        assertFalse(gateway.isDeploymentFeeEnabled());

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeploymentFeeEnabled(true);
        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        // Verify it's now enabled
        assertTrue(gateway.isDeploymentFeeEnabled());
    }

    // ============================================
    // .setDeploymentFee Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_setDeploymentFee_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, another));
        gateway.setDeploymentFee(10000, address(0), deployer);
    }

    /// @notice Should revert when fee token is zero address
    function test_setDeploymentFee_RevertWhen_FeeTokenIsZero() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        gateway.setDeploymentFee(10000, address(0), deployer);
    }

    /// @notice Should revert when fee collector is zero address
    function test_setDeploymentFee_RevertWhen_FeeCollectorIsZero() public {
        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(ZeroAddress.selector);
        gateway.setDeploymentFee(10000, address(feeToken), address(0));
    }

    /// @notice Should set deployment fee when called by owner
    function test_setDeploymentFee_Success() public {
        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.expectEmit(true, true, true, false, address(gateway));
        emit DeploymentFeeSet(10000, address(feeToken), deployer);
        vm.prank(deployer);
        gateway.setDeploymentFee(10000, address(feeToken), deployer);

        // Verify fee was set correctly
        ITREXGateway.Fee memory fee = gateway.getDeploymentFee();
        assertEq(fee.fee, 10000);
        assertEq(fee.feeToken, address(feeToken));
        assertEq(fee.feeCollector, deployer);
    }

    // ============================================
    // .addDeployer Tests
    // ============================================

    /// @notice Should revert when called by not admin
    function test_addDeployer_RevertWhen_NotAdmin() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.addDeployer(another);
    }

    /// @notice Should revert when deployer already exists
    function test_addDeployer_RevertWhen_DeployerAlreadyExists() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(tokenAgent);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(DeployerAlreadyExists.selector, tokenAgent));
        gateway.addDeployer(tokenAgent);
    }

    /// @notice Should add new deployer when called by owner
    function test_addDeployer_Success_WhenCalledByOwner() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertFalse(gateway.isDeployer(tokenAgent));

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerAdded(tokenAgent);
        vm.prank(deployer);
        gateway.addDeployer(tokenAgent);

        assertTrue(gateway.isDeployer(tokenAgent));
    }

    /// @notice Should add new deployer when called by agent
    function test_addDeployer_Success_WhenCalledByAgent() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertFalse(gateway.isDeployer(tokenAgent));

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerAdded(tokenAgent);
        vm.prank(tokenAgent);
        gateway.addDeployer(tokenAgent);

        assertTrue(gateway.isDeployer(tokenAgent));
    }

    // ============================================
    // .batchAddDeployer Tests
    // ============================================

    /// @notice Should revert when called by not admin
    function test_batchAddDeployer_RevertWhen_NotAdmin() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](1);
        deployers[0] = another;

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.batchAddDeployer(deployers);
    }

    /// @notice Should revert when batch includes already registered deployer
    function test_batchAddDeployer_RevertWhen_DeployerAlreadyExists() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(tokenAgent);

        address[] memory deployers = new address[](10);
        for (uint256 i = 0; i < 9; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
        }
        deployers[9] = tokenAgent; // Already exists

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(DeployerAlreadyExists.selector, tokenAgent));
        gateway.batchAddDeployer(deployers);
    }

    /// @notice Should revert when batch size exceeds 500
    function test_batchAddDeployer_RevertWhen_BatchSizeExceeds500() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](501);
        address duplicateAddress = makeAddr("duplicate");
        for (uint256 i = 0; i < 501; i++) {
            deployers[i] = duplicateAddress;
        }

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(BatchMaxLengthExceeded.selector, 500));
        gateway.batchAddDeployer(deployers);
    }

    /// @notice Should add 1 new deployer when called by owner
    function test_batchAddDeployer_Success_AddOneDeployer() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        assertFalse(gateway.isDeployer(tokenAgent));

        address[] memory deployers = new address[](1);
        deployers[0] = tokenAgent;

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerAdded(tokenAgent);
        vm.prank(deployer);
        gateway.batchAddDeployer(deployers);

        assertTrue(gateway.isDeployer(tokenAgent));
    }

    /// @notice Should add 10 new deployers when called by owner
    function test_batchAddDeployer_Success_AddTenDeployers() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
            assertFalse(gateway.isDeployer(deployers[i]));
        }

        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(true, false, false, false, address(gateway));
            emit DeployerAdded(deployers[i]);
        }
        vm.prank(deployer);
        gateway.batchAddDeployer(deployers);

        for (uint256 i = 0; i < 10; i++) {
            assertTrue(gateway.isDeployer(deployers[i]));
        }
    }

    /// @notice Should revert when agent tries to add batch with already registered deployer
    function test_batchAddDeployer_RevertWhen_AgentAddsAlreadyRegisteredDeployer() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addAgent(another);

        vm.prank(another);
        gateway.addDeployer(tokenAgent);

        address[] memory deployers = new address[](10);
        for (uint256 i = 0; i < 9; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
        }
        // Insert tokenAgent at random position (using position 5)
        deployers[5] = tokenAgent;

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(DeployerAlreadyExists.selector, tokenAgent));
        gateway.batchAddDeployer(deployers);
    }

    /// @notice Should add 1 new deployer when called by agent
    function test_batchAddDeployer_Success_WhenCalledByAgent() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addAgent(another);

        address[] memory deployers = new address[](1);
        deployers[0] = tokenAgent;

        assertFalse(gateway.isDeployer(tokenAgent));

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerAdded(tokenAgent);
        vm.prank(another);
        gateway.batchAddDeployer(deployers);

        assertTrue(gateway.isDeployer(tokenAgent));
    }

    /// @notice Should add 10 new deployers when called by agent
    function test_batchAddDeployer_Success_AgentAddsTenDeployers() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addAgent(another);

        address[] memory deployers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
            assertFalse(gateway.isDeployer(deployers[i]));
        }

        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(true, false, false, false, address(gateway));
            emit DeployerAdded(deployers[i]);
        }
        vm.prank(another);
        gateway.batchAddDeployer(deployers);

        for (uint256 i = 0; i < 10; i++) {
            assertTrue(gateway.isDeployer(deployers[i]));
        }
    }

    // ============================================
    // .removeDeployer Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_removeDeployer_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.removeDeployer(another);
    }

    /// @notice Should revert when deployer does not exist
    function test_removeDeployer_RevertWhen_DeployerDoesNotExist() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(DeployerDoesNotExist.selector, tokenAgent));
        gateway.removeDeployer(tokenAgent);
    }

    /// @notice Should remove deployer when called by owner
    function test_removeDeployer_Success() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(tokenAgent);

        assertTrue(gateway.isDeployer(tokenAgent));

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerRemoved(tokenAgent);
        vm.prank(deployer);
        gateway.removeDeployer(tokenAgent);

        assertFalse(gateway.isDeployer(tokenAgent));
    }

    // ============================================
    // .batchRemoveDeployer Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_batchRemoveDeployer_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](1);
        deployers[0] = another;

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.batchRemoveDeployer(deployers);
    }

    /// @notice Should revert when deployer does not exist
    function test_batchRemoveDeployer_RevertWhen_DeployerDoesNotExist() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](1);
        deployers[0] = tokenAgent;

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(DeployerDoesNotExist.selector, tokenAgent));
        gateway.batchRemoveDeployer(deployers);
    }

    /// @notice Should remove deployer when called by owner
    function test_batchRemoveDeployer_Success() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(tokenAgent);

        assertTrue(gateway.isDeployer(tokenAgent));

        address[] memory deployers = new address[](1);
        deployers[0] = tokenAgent;

        vm.expectEmit(true, false, false, false, address(gateway));
        emit DeployerRemoved(tokenAgent);
        vm.prank(deployer);
        gateway.batchRemoveDeployer(deployers);

        assertFalse(gateway.isDeployer(tokenAgent));
    }

    /// @notice Should revert when agent tries to remove non-existent deployer
    function test_batchRemoveDeployer_RevertWhen_AgentRemovesNonExistent() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        // Add 9 deployers first
        address[] memory deployers = new address[](9);
        for (uint256 i = 0; i < 9; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
        }

        vm.prank(deployer);
        gateway.batchAddDeployer(deployers);

        // Now create array with the 9 deployers + tokenAgent (who was never added as deployer)
        address[] memory deployersToRemove = new address[](10);
        for (uint256 i = 0; i < 9; i++) {
            deployersToRemove[i] = deployers[i];
        }
        deployersToRemove[9] = tokenAgent; // This one doesn't exist as a deployer

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(DeployerDoesNotExist.selector, tokenAgent));
        gateway.batchRemoveDeployer(deployersToRemove);
    }

    /// @notice Should revert when batch size exceeds 500
    function test_batchRemoveDeployer_RevertWhen_BatchSizeExceeds500() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address duplicateAddress = makeAddr("duplicate");
        address[] memory deployers = new address[](501);
        for (uint256 i = 0; i < 501; i++) {
            deployers[i] = duplicateAddress;
        }

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(abi.encodeWithSelector(BatchMaxLengthExceeded.selector, 500));
        gateway.batchRemoveDeployer(deployers);
    }

    /// @notice Should remove deployers when called by agent
    function test_batchRemoveDeployer_Success_WhenCalledByAgent() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
        }

        vm.prank(deployer);
        gateway.batchAddDeployer(deployers);

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(true, false, false, false, address(gateway));
            emit DeployerRemoved(deployers[i]);
        }
        vm.prank(tokenAgent);
        gateway.batchRemoveDeployer(deployers);

        for (uint256 i = 0; i < 10; i++) {
            assertFalse(gateway.isDeployer(deployers[i]));
        }
    }

    // ============================================
    // .applyFeeDiscount Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_applyFeeDiscount_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.applyFeeDiscount(another, 5000);
    }

    /// @notice Should revert when discount out of range
    function test_applyFeeDiscount_RevertWhen_DiscountOutOfRange() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        vm.expectRevert(DiscountOutOfRange.selector);
        gateway.applyFeeDiscount(another, 12000);
    }

    /// @notice Should apply discount when called by owner
    function test_applyFeeDiscount_Success() public {
        // Deploy a token to use as fee token BEFORE transferring ownership
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        address feeTokenAddress = trexFactory.getToken("salt");

        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, feeTokenAddress, deployer);

        assertEq(gateway.calculateFee(bob), 20000);

        vm.expectEmit(true, false, false, false, address(gateway));
        emit FeeDiscountApplied(bob, 5000);
        vm.prank(deployer);
        gateway.applyFeeDiscount(bob, 5000);

        assertEq(gateway.calculateFee(bob), 10000); // 50% discount
    }

    // ============================================
    // .batchApplyFeeDiscount Tests
    // ============================================

    /// @notice Should revert when called by not owner
    function test_batchApplyFeeDiscount_RevertWhen_NotOwner() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](1);
        deployers[0] = another;
        uint16[] memory discounts = new uint16[](1);
        discounts[0] = 5000;

        vm.prank(another);
        vm.expectRevert(SenderIsNotAdmin.selector);
        gateway.batchApplyFeeDiscount(deployers, discounts);
    }

    /// @notice Should revert when discount out of range
    function test_batchApplyFeeDiscount_RevertWhen_DiscountOutOfRange() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](1);
        deployers[0] = another;
        uint16[] memory discounts = new uint16[](1);
        discounts[0] = 12000;

        vm.prank(deployer);
        vm.expectRevert(DiscountOutOfRange.selector);
        gateway.batchApplyFeeDiscount(deployers, discounts);
    }

    /// @notice Should apply discounts when called by owner
    function test_batchApplyFeeDiscount_Success() public {
        // Deploy a token to use as fee token BEFORE transferring ownership
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        address feeTokenAddress = trexFactory.getToken("salt");

        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, feeTokenAddress, deployer);

        address[] memory deployers = new address[](2);
        deployers[0] = alice;
        deployers[1] = bob;
        uint16[] memory discounts = new uint16[](2);
        discounts[0] = 5000;
        discounts[1] = 10000;

        vm.expectEmit(true, false, false, false, address(gateway));
        emit FeeDiscountApplied(alice, 5000);
        vm.expectEmit(true, false, false, false, address(gateway));
        emit FeeDiscountApplied(bob, 10000);
        vm.prank(deployer);
        gateway.batchApplyFeeDiscount(deployers, discounts);

        assertEq(gateway.calculateFee(alice), 10000); // 50% discount
        assertEq(gateway.calculateFee(bob), 0); // 100% discount
    }

    /// @notice Should revert when agent tries to apply batch with out-of-range discount
    function test_batchApplyFeeDiscount_RevertWhen_AgentDiscountOutOfRange() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](10);
        uint16[] memory discounts = new uint16[](10);
        for (uint256 i = 0; i < 9; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
            discounts[i] = uint16(uint256(keccak256(abi.encodePacked(i))) % 10000); // Random discount 0-9999
        }
        deployers[9] = makeAddr("deployer9");
        discounts[9] = 12000; // Out of range

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        vm.prank(tokenAgent);
        vm.expectRevert(DiscountOutOfRange.selector);
        gateway.batchApplyFeeDiscount(deployers, discounts);
    }

    /// @notice Should revert when batch size exceeds 500
    function test_batchApplyFeeDiscount_RevertWhen_BatchSizeExceeds500() public {
        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        address[] memory deployers = new address[](501);
        uint16[] memory discounts = new uint16[](501);
        for (uint256 i = 0; i < 501; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
            discounts[i] = 5000;
        }

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(BatchMaxLengthExceeded.selector, 500));
        gateway.batchApplyFeeDiscount(deployers, discounts);
    }

    /// @notice Should apply discounts to all deployers when called by agent
    function test_batchApplyFeeDiscount_Success_WhenCalledByAgent() public {
        // Deploy a token to use as fee token BEFORE transferring ownership
        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(deployer);
        trexFactory.deployTREXSuite("salt", tokenDetails, claimDetails);
        address feeTokenAddress = trexFactory.getToken("salt");

        gateway = _deployGateway(address(0), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        uint256 deploymentFee = 20000;
        vm.prank(deployer);
        gateway.setDeploymentFee(deploymentFee, feeTokenAddress, deployer);

        address[] memory deployers = new address[](10);
        uint16[] memory discounts = new uint16[](10);
        for (uint256 i = 0; i < 10; i++) {
            deployers[i] = makeAddr(string(abi.encodePacked("deployer", i)));
            discounts[i] = 5000; // 50% discount
        }

        vm.prank(deployer);
        gateway.addAgent(tokenAgent);

        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(true, false, false, false, address(gateway));
            emit FeeDiscountApplied(deployers[i], discounts[i]);
        }

        vm.prank(tokenAgent);
        gateway.batchApplyFeeDiscount(deployers, discounts);

        uint256 expectedFeeAfterDiscount = deploymentFee - (deploymentFee * discounts[0]) / 10000;
        for (uint256 i = 0; i < 10; i++) {
            assertEq(gateway.calculateFee(deployers[i]), expectedFeeAfterDiscount);
        }
    }

    // ============================================
    // .deployTREXSuite Tests
    // ============================================

    /// @notice Should revert when called by not deployer and public deployments disabled
    function test_deployTREXSuite_RevertWhen_NotDeployerAndPublicDisabled() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(another);
        vm.expectRevert(PublicDeploymentsNotAllowed.selector);
        gateway.deployTREXSuite(tokenDetails, claimDetails);
    }

    /// @notice Should revert when public deployments enabled but trying to deploy on behalf
    function test_deployTREXSuite_RevertWhen_PublicEnabledButOnBehalf() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = bob; // Different from caller
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.prank(another);
        vm.expectRevert(PublicCannotDeployOnBehalf.selector);
        gateway.deployTREXSuite(tokenDetails, claimDetails);
    }

    /// @notice Should deploy for free when public deployments enabled and fees not activated
    function test_deployTREXSuite_Success_PublicEnabledNoFees() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 0);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);
    }

    /// @notice Should deploy with full fee when fees activated and no discount
    function test_deployTREXSuite_Success_FullFee() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 100000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(another);
        feeToken.approve(address(gateway), 20000);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 20000);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);

        assertEq(feeToken.balanceOf(another), 80000);
    }

    /// @notice Should deploy with 50% discount when caller has discount
    function test_deployTREXSuite_Success_HalfFeeWithDiscount() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 100000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(deployer);
        gateway.applyFeeDiscount(another, 5000); // 50% discount

        vm.prank(another);
        feeToken.approve(address(gateway), 20000);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 10000);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);

        assertEq(feeToken.balanceOf(another), 90000);
    }

    /// @notice Should deploy for free when deployer has 100% discount
    function test_deployTREXSuite_Success_DeployerFreeWithFullDiscount() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 100000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(deployer);
        gateway.applyFeeDiscount(another, 10000); // 100% discount

        vm.prank(another);
        feeToken.approve(address(gateway), 20000);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 0);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);

        assertEq(feeToken.balanceOf(another), 100000); // No fee deducted
    }

    /// @notice Should deploy when called by deployer with public deployments disabled
    function test_deployTREXSuite_Success_WhenCalledByDeployer() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 0);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);
    }

    /// @notice Should deploy on behalf when called by deployer
    function test_deployTREXSuite_Success_DeployOnBehalf() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = bob; // Different from caller, but deployer can do this
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, bob, 0);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);
    }

    /// @notice Should deploy with full fee when deployer has no discount
    function test_deployTREXSuite_Success_DeployerFullFee() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 100000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(another);
        feeToken.approve(address(gateway), 20000);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 20000);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);

        assertEq(feeToken.balanceOf(another), 80000);
    }

    /// @notice Should deploy with 50% discount when deployer has discount
    function test_deployTREXSuite_Success_DeployerHalfFeeWithDiscount() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 100000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(deployer);
        gateway.applyFeeDiscount(another, 5000); // 50% discount

        vm.prank(another);
        feeToken.approve(address(gateway), 20000);

        ITREXFactory.TokenDetails memory tokenDetails = _createEmptyTokenDetails();
        tokenDetails.owner = another;
        ITREXFactory.ClaimDetails memory claimDetails = _createEmptyClaimDetails();

        vm.expectEmit(false, false, false, true, address(gateway));
        emit GatewaySuiteDeploymentProcessed(another, another, 10000);
        vm.prank(another);
        gateway.deployTREXSuite(tokenDetails, claimDetails);

        assertEq(feeToken.balanceOf(another), 90000);
    }

    // ============================================
    // .batchDeployTREXSuite Tests
    // ============================================

    /// @notice Should revert when called by not deployer and public deployments disabled
    function test_batchDeployTREXSuite_RevertWhen_NotDeployerAndPublicDisabled() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        vm.prank(another);
        vm.expectRevert(PublicDeploymentsNotAllowed.selector);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    /// @notice Should revert when trying to deploy on behalf in batch
    function test_batchDeployTREXSuite_RevertWhen_PublicEnabledButOnBehalf() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 4; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }
        // Last one has different owner
        tokenDetailsArray[4] = _createEmptyTokenDetails();
        tokenDetailsArray[4].name = "Token name behalf";
        tokenDetailsArray[4].symbol = "SYM42";
        tokenDetailsArray[4].owner = bob;
        claimDetailsArray[4] = _createEmptyClaimDetails();

        vm.prank(another);
        vm.expectRevert(PublicCannotDeployOnBehalf.selector);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    /// @notice Should revert when batch size exceeds 5
    function test_batchDeployTREXSuite_RevertWhen_BatchSizeExceeds5() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](6);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](6);

        for (uint256 i = 0; i < 6; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        vm.prank(another);
        vm.expectRevert(abi.encodeWithSelector(BatchMaxLengthExceeded.selector, 5));
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    /// @notice Should deploy tokens for free in batch when fees not activated
    function test_batchDeployTREXSuite_Success_NoFees() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.expectEmit(false, false, false, true, address(gateway));
            emit GatewaySuiteDeploymentProcessed(another, another, 0);
        }
        vm.prank(another);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    /// @notice Should deploy tokens for full fee in batch
    function test_batchDeployTREXSuite_Success_FullFee() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 500000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(another);
        feeToken.approve(address(gateway), 100000);

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.expectEmit(false, false, false, true, address(gateway));
            emit GatewaySuiteDeploymentProcessed(another, another, 20000);
        }

        vm.prank(another);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);

        assertEq(feeToken.balanceOf(another), 400000);
    }

    /// @notice Should deploy tokens for half fee in batch with discount
    function test_batchDeployTREXSuite_Success_HalfFeeWithDiscount() public {
        gateway = _deployGateway(address(trexFactory), true);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        TestERC20 feeToken = new TestERC20("FeeToken", "FT");
        feeToken.mint(another, 500000);

        vm.prank(deployer);
        gateway.setDeploymentFee(20000, address(feeToken), deployer);

        vm.prank(deployer);
        gateway.enableDeploymentFee(true);

        vm.prank(deployer);
        gateway.applyFeeDiscount(another, 5000); // 50% discount

        vm.prank(another);
        feeToken.approve(address(gateway), 50000);

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.expectEmit(false, false, false, true, address(gateway));
            emit GatewaySuiteDeploymentProcessed(another, another, 10000);
        }
        vm.prank(another);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);

        assertEq(feeToken.balanceOf(another), 450000);
    }

    /// @notice Should deploy in batch when called by deployer
    function test_batchDeployTREXSuite_Success_WhenCalledByDeployer() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = another;
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.expectEmit(false, false, false, true, address(gateway));
            emit GatewaySuiteDeploymentProcessed(another, another, 0);
        }

        vm.prank(another);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    /// @notice Should deploy on behalf in batch when called by deployer
    function test_batchDeployTREXSuite_Success_DeployOnBehalf() public {
        gateway = _deployGateway(address(trexFactory), false);
        vm.prank(deployer);
        trexFactory.transferOwnership(address(gateway));

        vm.prank(deployer);
        gateway.addDeployer(another);

        ITREXFactory.TokenDetails[] memory tokenDetailsArray = new ITREXFactory.TokenDetails[](5);
        ITREXFactory.ClaimDetails[] memory claimDetailsArray = new ITREXFactory.ClaimDetails[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDetailsArray[i] = _createEmptyTokenDetails();
            tokenDetailsArray[i].name = string(abi.encodePacked("Token name ", vm.toString(i)));
            tokenDetailsArray[i].symbol = string(abi.encodePacked("SYM", vm.toString(i)));
            tokenDetailsArray[i].owner = bob; // Different from caller
            claimDetailsArray[i] = _createEmptyClaimDetails();
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.expectEmit(false, false, false, true, address(gateway));
            emit GatewaySuiteDeploymentProcessed(another, bob, 0);
        }

        vm.prank(another);
        gateway.batchDeployTREXSuite(tokenDetailsArray, claimDetailsArray);
    }

    // ============================================
    // .supportsInterface Tests
    // ============================================

    /// @notice Should return false for unsupported interfaces
    function test_supportsInterface_ReturnsFalse_ForUnsupportedInterface() public {
        gateway = _deployGateway(address(trexFactory), false);

        bytes4 unsupportedInterfaceId = 0x12345678;
        assertFalse(gateway.supportsInterface(unsupportedInterfaceId));
    }

    /// @notice Should correctly identify the ITREXGateway interface ID
    function test_supportsInterface_ReturnsTrue_ForITREXGateway() public {
        gateway = _deployGateway(address(trexFactory), false);

        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getITREXGatewayInterfaceId();
        assertTrue(gateway.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC173 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC173() public {
        gateway = _deployGateway(address(trexFactory), false);

        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC173InterfaceId();
        assertTrue(gateway.supportsInterface(interfaceId));
    }

    /// @notice Should correctly identify the IERC165 interface ID
    function test_supportsInterface_ReturnsTrue_ForIERC165() public {
        gateway = _deployGateway(address(trexFactory), false);

        InterfaceIdCalculator calculator = new InterfaceIdCalculator();
        bytes4 interfaceId = calculator.getIERC165InterfaceId();
        assertTrue(gateway.supportsInterface(interfaceId));
    }

}
