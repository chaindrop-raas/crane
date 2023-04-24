// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import {GovernorQuorum} from "src/governor/lib/GovernorQuorum.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";
import {ERC20Base} from "src/token/governance/ERC20Base.sol";

contract QuorumContract {
    address public governanceToken;

    constructor(address govToken, uint128 numerator, uint128 denominator) {
        governanceToken = govToken;

        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        cs.votingDelay = 1 days;
        cs.votingPeriod = 2 days;
        cs.quorumNumerator = numerator;
        cs.quorumDenominator = denominator;
        cs.proposalThresholdToken = govToken;
        cs.proposalThreshold = 100;
    }

    function createProposal(uint256 proposalId) public {
        GovernorStorage.createProposal(proposalId, governanceToken, TokenWeightStrategy.simpleWeightSelector);
    }

    function quorumNumerator(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorumNumerator(proposalId);
    }

    function quorumDenominator(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorumDenominator(proposalId);
    }

    function quorum(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorum(proposalId);
    }
}

contract QuorumContractTest is GovernorDiamondHelper {
    QuorumContract public quorumContract;

    function setUp() public {
        quorumContract = new QuorumContract(address(govToken), 10, 100);
        quorumContract.createProposal(42);
        vm.roll(86443);
    }

    function testGetQuorumNumerator() public {
        assertEq(quorumContract.quorumNumerator(42), 10);
    }

    function testGetQuorumDenominator() public {
        assertEq(quorumContract.quorumDenominator(42), 100);
    }

    function testQuorum() public {
        assertEq(ERC20Base(govToken).totalSupply(), 843750000);
        // 10% of the above total supply
        assertEq(quorumContract.quorum(42), 84375000);
    }
}

contract NonStandardQuorumContractTest is GovernorDiamondHelper {
    QuorumContract public quorumContract;

    function setUp() public {
        quorumContract = new QuorumContract(address(govToken), 25, 10000);
        quorumContract.createProposal(43);
        vm.roll(86443);
    }

    function testGetQuorumNumerator() public {
        assertEq(quorumContract.quorumNumerator(43), 25);
    }

    function testGetQuorumDenominator() public {
        assertEq(quorumContract.quorumDenominator(43), 10000);
    }

    function testQuorum() public {
        assertEq(ERC20Base(govToken).totalSupply(), 843750000);
        // 10% of the above total supply
        assertEq(quorumContract.quorum(43), 2109375);
    }
}
