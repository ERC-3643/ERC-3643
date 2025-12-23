// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC2612ExpiredSignature, ERC2612InvalidSigner } from "contracts/token/TokenPermit.sol";
import { TokenTestBase } from "test/token/TokenTestBase.sol";

contract TokenPermitTest is TokenTestBase {

    uint256 constant VALUE = 42;
    uint256 constant NONCE = 0;
    uint256 constant MAX_DEADLINE = type(uint256).max;

    // Additional test addresses
    uint256 public alicePrivateKey = 0x1; // Private key for alice
    address public aliceSigner = vm.addr(alicePrivateKey); // alice address from private key
    uint256 public bobPrivateKey = 0x2; // Private key for bob
    address public bobSigner = vm.addr(bobPrivateKey); // bob address from private key

    function setUp() public override {
        super.setUp();

        // Add tokenAgent as an agent
        vm.prank(deployer);
        token.addAgent(tokenAgent);

        // Unpause token
        vm.prank(tokenAgent);
        token.unpause();
    }

    /// @notice Helper function to get EIP-712 domain separator
    function _getDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(token.name())),
                keccak256(bytes(token.version())),
                block.chainid,
                address(token)
            )
        );
    }

    /// @notice Helper function to build permit signature
    function _buildPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitTypeHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, owner, spender, value, nonce, deadline));
        bytes32 domainSeparator = _getDomainSeparator();
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        return vm.sign(privateKey, typedDataHash);
    }

    // ============ Initial state Tests ============

    /// @notice Initial nonce is 0
    function test_InitialNonce_IsZero() public view {
        assertEq(token.nonces(alice), 0);
        assertEq(token.nonces(bob), 0);
        assertEq(token.nonces(another), 0);
    }

    /// @notice Domain separator should match computed value
    function test_DomainSeparator_Matches() public view {
        bytes32 expectedDomainSeparator = _getDomainSeparator();
        assertEq(token.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    // ============ Permit Tests ============

    /// @notice Accepts owner signature
    function test_permit_AcceptsOwnerSignature() public {
        // Use alice and bob from TREXFactorySetup, but we need to sign with a known private key
        // So we'll use the addresses that correspond to known private keys
        address owner = aliceSigner;
        address spender = bobSigner;

        (uint8 v, bytes32 r, bytes32 s) =
            _buildPermitSignature(owner, spender, VALUE, NONCE, MAX_DEADLINE, alicePrivateKey);

        token.permit(owner, spender, VALUE, MAX_DEADLINE, v, r, s);

        assertEq(token.nonces(owner), 1);
        assertEq(token.allowance(owner, spender), VALUE);
    }

    /// @notice Rejects reused signature
    function test_permit_RejectsReusedSignature() public {
        address owner = aliceSigner;
        address spender = bobSigner;

        (uint8 v, bytes32 r, bytes32 s) =
            _buildPermitSignature(owner, spender, VALUE, NONCE, MAX_DEADLINE, alicePrivateKey);

        // First permit succeeds
        token.permit(owner, spender, VALUE, MAX_DEADLINE, v, r, s);

        // When trying to reuse the signature, the nonce has increased to 1
        // The contract will check the signature against nonce=1, which will recover to a different address
        // Calculate what address the signature would recover to with the new nonce
        bytes32 permitTypeHash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, owner, spender, VALUE, 1, MAX_DEADLINE));
        bytes32 domainSeparator = _getDomainSeparator();
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address recovered = ecrecover(typedDataHash, v, r, s);

        // Try to reuse the same signature (nonce has increased, so signature recovers to wrong address)
        vm.expectRevert(abi.encodeWithSelector(ERC2612InvalidSigner.selector, recovered, owner));
        token.permit(owner, spender, VALUE, MAX_DEADLINE, v, r, s);
    }

    /// @notice Rejects other signature
    function test_permit_RejectsOtherSignature() public {
        address owner = aliceSigner;
        address spender = bobSigner;

        // Sign with bob's private key instead of alice's
        (uint8 v, bytes32 r, bytes32 s) =
            _buildPermitSignature(owner, spender, VALUE, NONCE, MAX_DEADLINE, bobPrivateKey);

        vm.expectRevert(abi.encodeWithSelector(ERC2612InvalidSigner.selector, bobSigner, owner));
        token.permit(owner, spender, VALUE, MAX_DEADLINE, v, r, s);
    }

    /// @notice Rejects expired permit
    function test_permit_RejectsExpiredPermit() public {
        address owner = aliceSigner;
        address spender = bobSigner;

        // Set deadline to past (1 week ago)
        vm.warp(block.timestamp + 7 days);
        uint256 deadline = block.timestamp - 7 days;

        (uint8 v, bytes32 r, bytes32 s) = _buildPermitSignature(owner, spender, VALUE, NONCE, deadline, alicePrivateKey);

        vm.expectRevert(abi.encodeWithSelector(ERC2612ExpiredSignature.selector, deadline));
        token.permit(owner, spender, VALUE, deadline, v, r, s);
    }

    // ============ eip712Domain() Tests ============

    /// @notice Should return correct EIP-712 domain information
    function test_eip712Domain_ReturnsCorrectValues() public view {
        (
            bytes1 fields,
            string memory name_,
            string memory version_,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = token.eip712Domain();

        assertEq(fields, hex"0f");
        assertEq(keccak256(bytes(name_)), keccak256(bytes(token.name())));
        assertEq(keccak256(bytes(version_)), keccak256(bytes(token.version())));
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(token));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

}
