// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import "src/governor/lib/GovernorQuorum.sol";
import "src/governor/lib/TokenWeightStrategy.sol";

contract QuorumContract {
    address public governanceToken;

    constructor(address govToken) {
        governanceToken = govToken;

        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        cs.votingDelay = 1 days;
        cs.votingPeriod = 2 days;
        cs.quorumNumerator = 10;
        cs.proposalThresholdToken = govToken;
        cs.proposalThreshold = 100;
    }

    function createProposal(uint256 proposalId) public {
        GovernorStorage.createProposal(proposalId, governanceToken, TokenWeightStrategy.simpleWeightSelector);
    }

    function quorumNumerator(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorumNumerator(proposalId);
    }

    function quorumDenominator() public pure returns (uint256) {
        return GovernorQuorum.quorumDenominator();
    }

    function quorum(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorum(proposalId);
    }
}

contract QuorumContractTest is GovernorDiamondHelper {
    QuorumContract public quorumContract;

    function setUp() public {
        quorumContract = new QuorumContract(address(govToken));
        quorumContract.createProposal(42);
        vm.roll(86443);
    }

    function testGetQuorumNumerator() public {
        assertEq(quorumContract.quorumNumerator(42), 10);
    }

    function testGetQuorumDenominator() public {
        assertEq(quorumContract.quorumDenominator(), 100);
    }

    function testQuorum() public {
        assertEq(quorumContract.quorum(42), 84375000);
    }
}
