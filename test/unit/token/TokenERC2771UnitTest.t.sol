// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import { ERC2771Forwarder } from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { ERC3643EventsLib } from "contracts/ERC-3643/ERC3643EventsLib.sol";
import { IERC3643IdentityRegistry } from "contracts/ERC-3643/IERC3643IdentityRegistry.sol";
import { EventsLib } from "contracts/libraries/EventsLib.sol";
import { RolesLib } from "contracts/libraries/RolesLib.sol";
import { IIdentityRegistry } from "contracts/registry/interface/IIdentityRegistry.sol";

import { TokenBaseUnitTest } from "../helpers/TokenBaseUnitTest.t.sol";

contract TokenERC2771UnitTest is TokenBaseUnitTest {

    address relayer = makeAddr("Relayer");

    ERC2771Forwarder forwarder = new ERC2771Forwarder("ERC3643-Token");

    Account account1 = makeAccount("TestUser1");
    Account account2 = makeAccount("TestUser2");
    Account agentAccount = makeAccount("AgentAccount");

    function setUp() public override {
        super.setUp();

        token.setTrustedForwarder(address(forwarder));

        _setRoles(address(this), agentAccount.addr);

        vm.startPrank(agent);
        token.unpause();
        token.mint(account1.addr, 1000);
        vm.stopPrank();
    }

    /* ----- Tests for transfer() - uses _msgSender() ----- */

    function testTransferViaForwarder() public {
        // Create forward request for transfer
        bytes memory transferData = abi.encodeWithSelector(token.transfer.selector, account2.addr, uint256(100));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account1, address(token), 0, 200000, deadline, transferData);

        // Execute via forwarder (relayer pays gas)
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify transfer succeeded - _msgSender() should return account1.addr
        assertEq(token.balanceOf(account1.addr), 900);
        assertEq(token.balanceOf(account2.addr), 100);
    }

    /* ----- Tests for transferFrom() - uses _msgSender() ----- */

    function testTransferFromViaForwarder() public {
        // account1 approves account2 to spend
        vm.prank(account1.addr);
        token.approve(account2.addr, 200);

        // Create forward request for transferFrom (account2 transfers from account1)
        bytes memory transferFromData =
            abi.encodeWithSelector(token.transferFrom.selector, account1.addr, account2.addr, uint256(150));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account2, address(token), 0, 200000, deadline, transferFromData);

        // Execute via forwarder - _msgSender() should return account2.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify transfer succeeded
        assertEq(token.balanceOf(account1.addr), 850);
        assertEq(token.balanceOf(account2.addr), 150);
    }

    /* ----- Tests for setDefaultAllowance() - uses _msgSender() ----- */

    function testSetDefaultAllowanceViaForwarder() public {
        // Create forward request for setDefaultAllowance
        bytes memory setDefaultAllowanceData = abi.encodeCall(token.setDefaultAllowance, (false));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account1, address(token), 0, 200000, deadline, setDefaultAllowanceData);

        // Expect event with account1.addr as sender
        vm.expectEmit(true, true, true, true);
        emit EventsLib.DefaultAllowanceOptOutUpdated(account1.addr, true);

        // Execute via forwarder - _msgSender() should return account1.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify the opt-out was set by trying to set it again (should revert if already set)
        bytes memory setDefaultAllowanceData2 = abi.encodeCall(token.setDefaultAllowance, (false));
        uint48 deadline2 = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request2 =
            _createForwardRequest(account1, address(token), 0, 200000, deadline2, setDefaultAllowanceData2);

        vm.prank(relayer);
        vm.expectRevert();
        forwarder.execute(request2);
    }

    /* ----- Tests for setAllowanceForAll() - uses _msgSender() (onlyOwner) ----- */

    function testSetAllowanceForAllViaForwarder() public {
        Account memory ownerAccount = makeAccount("OwnerAccount");
        vm.prank(accessManagerAdmin);
        accessManager.grantRole(RolesLib.SPENDING_ADMIN, ownerAccount.addr, 0);

        address[] memory targets = new address[](1);
        targets[0] = account1.addr;

        // Create forward request for setAllowanceForAll
        bytes memory setAllowanceForAllData = abi.encodeCall(token.setAllowanceForAll, (targets, true));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(ownerAccount, address(token), 0, 200000, deadline, setAllowanceForAllData);

        vm.prank(relayer);
        forwarder.execute(request);
    }

    /* ----- Tests for pause() - uses _msgSender() (onlyAgent) ----- */

    function testPauseViaForwarder() public {
        // Create forward request for pause
        bytes memory pauseData = abi.encodeWithSelector(token.pause.selector);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, pauseData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify token is paused
        assertTrue(token.paused());
    }

    /* ----- Tests for unpause() - uses _msgSender() (onlyAgent) ----- */

    function testUnpauseViaForwarder() public {
        vm.prank(agent);
        token.pause();

        // Create forward request for unpause
        bytes memory unpauseData = abi.encodeWithSelector(token.unpause.selector);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, unpauseData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify token is unpaused
        assertFalse(token.paused());
    }

    /* ----- Tests for mint() - uses _msgSender() (onlyAgent) ----- */

    function testMintViaForwarder() public {
        uint256 balanceBefore = token.balanceOf(account1.addr);

        // Create forward request for mint
        bytes memory mintData = abi.encodeCall(token.mint, (account1.addr, uint256(1000)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, mintData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify mint succeeded
        assertEq(token.balanceOf(account1.addr), balanceBefore + 1000);
    }

    /* ----- Tests for burn() - uses _msgSender() (onlyAgent) ----- */

    function testBurnViaForwarder() public {
        // Create forward request for burn
        bytes memory burnData = abi.encodeCall(token.burn, (account1.addr, uint256(300)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, burnData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify burn succeeded
        assertEq(token.balanceOf(account1.addr), 700);
    }

    /* ----- Tests for freezePartialTokens() - uses _msgSender() (onlyAgent) ----- */

    function testFreezePartialTokensViaForwarder() public {
        // Create forward request for freezePartialTokens
        bytes memory freezeData = abi.encodeCall(token.freezePartialTokens, (account1.addr, uint256(200)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, freezeData);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit ERC3643EventsLib.TokensFrozen(account1.addr, 200);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify freeze succeeded
        assertEq(token.getFrozenTokens(account1.addr), 200);
    }

    /* ----- Tests for unfreezePartialTokens() - uses _msgSender() (onlyAgent) ----- */

    function testUnfreezePartialTokensViaForwarder() public {
        vm.prank(agent);
        token.freezePartialTokens(account1.addr, 300);

        // Create forward request for unfreezePartialTokens
        bytes memory unfreezeData = abi.encodeCall(token.unfreezePartialTokens, (account1.addr, uint256(100)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, unfreezeData);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit ERC3643EventsLib.TokensUnfrozen(account1.addr, 100);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify unfreeze succeeded
        assertEq(token.getFrozenTokens(account1.addr), 200);
    }

    /* ----- Tests for setAddressFrozen() - uses _msgSender() (onlyAgent) ----- */

    function testSetAddressFrozenViaForwarder() public {
        // Create forward request for setAddressFrozen
        bytes memory freezeAddressData = abi.encodeCall(token.setAddressFrozen, (account1.addr, true));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, freezeAddressData);

        // Expect event with agentAccount.addr as sender
        vm.expectEmit(true, true, true, true);
        emit ERC3643EventsLib.AddressFrozen(account1.addr, true, agentAccount.addr);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify address is frozen
        assertTrue(token.isFrozen(account1.addr));
    }

    /* ----- Tests for recoveryAddress() - uses _msgSender() (onlyAgent) ----- */

    function testRecoveryAddressViaForwarder() public {
        address identityRegistryAddr = address(token.identityRegistry());

        // Setup: mock identity registry contains function
        vm.mockCall(
            identityRegistryAddr,
            abi.encodeWithSelector(IERC3643IdentityRegistry.contains.selector, account1.addr),
            abi.encode(true)
        );
        vm.mockCall(
            identityRegistryAddr,
            abi.encodeWithSelector(IERC3643IdentityRegistry.contains.selector, account2.addr),
            abi.encode(false)
        );
        vm.mockCall(
            identityRegistryAddr,
            abi.encodeWithSelector(IIdentityRegistry.isLocallyRegistered.selector, account1.addr),
            abi.encode(true)
        );
        vm.mockCall(
            identityRegistryAddr,
            abi.encodeWithSelector(IIdentityRegistry.isLocallyRegistered.selector, account2.addr),
            abi.encode(false)
        );
        vm.mockCall(
            identityRegistryAddr, abi.encodeWithSelector(IERC3643IdentityRegistry.registerIdentity.selector), ""
        );

        // Create forward request for recoveryAddress
        bytes memory recoveryData = abi.encodeCall(token.recoveryAddress, (account1.addr, account2.addr, address(0)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 300000, deadline, recoveryData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        // Note: The forwarder emits ExecutedForwardRequest event, not RecoverySuccess directly
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify recovery succeeded - tokens moved to account2
        assertEq(token.balanceOf(account2.addr), 1000);
        assertEq(token.balanceOf(account1.addr), 0);
    }

    /* ----- Tests for forcedTransfer() - uses _msgSender() (onlyAgent) ----- */

    function testForcedTransferViaForwarder() public {
        // Create forward request for forcedTransfer
        bytes memory forcedTransferData =
            abi.encodeCall(token.forcedTransfer, (account1.addr, account2.addr, uint256(500)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(agentAccount, address(token), 0, 200000, deadline, forcedTransferData);

        // Execute via forwarder - _msgSender() should return agentAccount.addr
        vm.prank(relayer);
        forwarder.execute(request);

        // Verify forced transfer succeeded
        assertEq(token.balanceOf(account1.addr), 500);
        assertEq(token.balanceOf(account2.addr), 500);
    }

    /* ----- Error Cases ----- */

    function testTransferViaForwarderRevertsWhenNotAgent() public {
        // Create forward request for mint (agent-only function) from non-agent
        bytes memory mintData = abi.encodeCall(token.mint, (account2.addr, uint256(1000)));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account1, address(token), 0, 200000, deadline, mintData);

        // Should revert because account1 is not an agent
        // The forwarder wraps the error, so we check for any revert
        vm.prank(relayer);
        vm.expectRevert();
        forwarder.execute(request);

        // Verify mint did not succeed
        assertEq(token.balanceOf(account2.addr), 0);
    }

    function testTransferViaForwarderRevertsWhenExpired() public {
        // Create forward request with expired deadline
        bytes memory transferData = abi.encodeWithSelector(token.transfer.selector, account2.addr, uint256(100));
        uint48 deadline = uint48(block.timestamp - 1);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account1, address(token), 0, 200000, deadline, transferData);

        // Should revert because request is expired
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(ERC2771Forwarder.ERC2771ForwarderExpiredRequest.selector, deadline));
        forwarder.execute(request);
    }

    function testTransferViaForwarderRevertsWhenNotTrusted() public {
        // Remove trusted forwarder
        token.setTrustedForwarder(address(0xF0F0));

        // Create forward request
        bytes memory transferData = abi.encodeWithSelector(token.transfer.selector, account2.addr, uint256(100));
        uint48 deadline = uint48(block.timestamp + 1 hours);
        ERC2771Forwarder.ForwardRequestData memory request =
            _createForwardRequest(account1, address(token), 0, 200000, deadline, transferData);

        // Should revert because token doesn't trust the forwarder
        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC2771Forwarder.ERC2771UntrustfulTarget.selector, address(token), address(forwarder)
            )
        );
        forwarder.execute(request);
    }

    /* ----- Helper Functions ----- */

    function _createForwardRequest(
        Account memory from,
        address to,
        uint256 value,
        uint256 gas,
        uint48 deadline,
        bytes memory data
    ) internal view returns (ERC2771Forwarder.ForwardRequestData memory request) {
        uint256 nonce = forwarder.nonces(from.addr);

        request = ERC2771Forwarder.ForwardRequestData({
            from: from.addr, to: to, value: value, gas: gas, deadline: deadline, data: data, signature: ""
        });

        // Compute the EIP712 hash using the forwarder's domain
        bytes32 digest = _hashForwardRequest(from.addr, to, value, gas, nonce, deadline, data);

        // Sign with the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(from.key, digest);

        request.signature = abi.encodePacked(r, s, v);
    }

    function _hashForwardRequest(
        address from,
        address to,
        uint256 value,
        uint256 gas,
        uint256 nonce,
        uint48 deadline,
        bytes memory data
    ) internal view returns (bytes32) {
        bytes32 TYPE_HASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 FORWARD_REQUEST_TYPEHASH = keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

        // Build domain separator matching the forwarder's domain
        bytes32 domainSeparator = keccak256(
            abi.encode(
                TYPE_HASH, keccak256(bytes("ERC3643-Token")), keccak256(bytes("1")), block.chainid, address(forwarder)
            )
        );

        // Build struct hash
        bytes32 structHash =
            keccak256(abi.encode(FORWARD_REQUEST_TYPEHASH, from, to, value, gas, nonce, deadline, keccak256(data)));

        // Build final digest
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

}
