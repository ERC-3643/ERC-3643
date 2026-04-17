// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "../registry/interface/IIdentityVerifier.sol";

/**
 * @title FixedAnswerVerifier
 * @dev Test-only IIdentityVerifier that returns a compile-time-fixed answer.
 *      Used by IdentityRegistry tests to exercise the pluggable verifier path.
 */
contract FixedAnswerVerifier is IIdentityVerifier {
    bool public immutable answer;

    constructor(bool _answer) {
        answer = _answer;
    }

    function isVerified(address) external view override returns (bool) {
        return answer;
    }
}
