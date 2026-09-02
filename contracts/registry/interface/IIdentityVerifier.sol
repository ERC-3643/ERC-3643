// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

/**
 * @title IIdentityVerifier
 * @dev Minimal pluggable interface used by IdentityRegistry to delegate
 *      verification to an external verifier contract (e.g. an attestation-
 *      backed KYC/AML oracle).
 *
 *      When an IdentityRegistry has a non-zero verifier configured via
 *      `setIdentityVerifier`, its `isVerified(wallet)` call is short-circuited
 *      to this interface, bypassing the built-in ONCHAINID-based verification.
 *      Setting the verifier back to address(0) restores the default behaviour.
 */
interface IIdentityVerifier {
    /**
     * @dev Returns whether `_userAddress` is considered verified.
     * @param _userAddress The wallet to check.
     * @return True if the address is verified, false otherwise.
     */
    function isVerified(address _userAddress) external view returns (bool);
}
