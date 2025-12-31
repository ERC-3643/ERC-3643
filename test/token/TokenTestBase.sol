// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ITREXFactory } from "contracts/factory/ITREXFactory.sol";
import { Token } from "contracts/token/Token.sol";
import { TREXFactorySetup } from "test/helpers/TREXFactorySetup.sol";

contract TokenTestBase is TREXFactorySetup {

    Token public token;

    // Common test agent address
    address public tokenAgent = makeAddr("tokenAgent");

    function setUp() public virtual override {
        super.setUp();

        // Deploy token suite with default empty configuration
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
        token = Token(trexFactory.getToken("salt"));
    }

}
