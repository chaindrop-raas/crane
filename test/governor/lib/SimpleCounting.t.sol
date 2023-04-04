// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import {SimpleCounting} from "src/governor/lib/SimpleCounting.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

contract SimpleContract {
    constructor() {
        GovernorStorage.proposal(1).countingStrategy = TokenWeightStrategy.simpleWeightSelector;
    }

    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure returns (string memory) {
        return SimpleCounting.COUNTING_MODE();
    }

    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight) public {
        SimpleCounting.setVote(proposalId, account, support, weight);
    }

    function getVote(uint256 proposalId, address account)
        public
        view
        returns (SimpleCounting.VoteType, uint256, uint256)
    {
        return SimpleCounting.getVote(proposalId, account);
    }

    function getProposalVoters(uint256 proposalId) public view returns (address[] memory) {
        return SimpleCounting.getProposalVoters(proposalId);
    }

    function simpleProposalVotes(uint256 proposalId) public view returns (uint256, uint256, uint256) {
        return SimpleCounting.simpleProposalVotes(proposalId);
    }

    function winningOption(uint256 proposalId) public view returns (SimpleCounting.VoteType) {
        return SimpleCounting.winningOption(proposalId);
    }

    function voteSucceeded(uint256 proposalId) public view returns (bool) {
        return SimpleCounting.voteSucceeded(proposalId);
    }
}

contract SimpleCountingLibTest is GovernorDiamondHelper {
    SimpleContract public simpleContract;

    function setUp() public {
        simpleContract = new SimpleContract();
    }

    function testCountingMode() public {
        assertEq(simpleContract.COUNTING_MODE(), "support=bravo&quorum=for,abstain");
    }

    function testVotePersistence() public {
        simpleContract.setVote(1, address(0x1), 0, 100);
        (SimpleCounting.VoteType voteType, uint256 weight, uint256 calculatedWeight) =
            simpleContract.getVote(1, address(0x1));
        assertEq(uint8(voteType), 0);
        assertEq(weight, 100);
        assertEq(calculatedWeight, 100);
    }

    function testGetProposalVoters() public {
        address[] memory voters = new address[](3);
        voters[0] = address(0x1);
        voters[1] = address(0x2);
        voters[2] = address(0x3);

        for (uint256 i = 0; i < voters.length; i++) {
            simpleContract.setVote(1, address(voters[i]), 1, 100);
        }

        address[] memory proposalVoters = simpleContract.getProposalVoters(1);
        assertEq(abi.encode(proposalVoters), abi.encode(voters));
    }

    function testSimpleProposalVotes() public {
        simpleContract.setVote(1, address(0x1), 1, 300);
        simpleContract.setVote(1, address(0x2), 1, 100);
        simpleContract.setVote(1, address(0x3), 0, 300);
        simpleContract.setVote(1, address(0x4), 2, 600);

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = simpleContract.simpleProposalVotes(1);
        assertEq(forVotes, 400);
        assertEq(againstVotes, 300);
        assertEq(abstainVotes, 600);
    }

    function testWinningOptionFor() public {
        simpleContract.setVote(1, address(0x1), 1, 300);
        simpleContract.setVote(1, address(0x2), 1, 100);
        simpleContract.setVote(1, address(0x3), 0, 300);
        simpleContract.setVote(1, address(0x4), 2, 600);

        assertEq(uint8(simpleContract.winningOption(1)), 1);
    }

    function testWinningOptionAgainst() public {
        simpleContract.setVote(1, address(0x1), 1, 300);
        simpleContract.setVote(1, address(0x2), 0, 100);
        simpleContract.setVote(1, address(0x3), 0, 300);
        simpleContract.setVote(1, address(0x4), 2, 600);

        assertEq(uint8(simpleContract.winningOption(1)), 0);
    }

    function testVoteSucceeded() public {
        simpleContract.setVote(1, address(0x1), 1, 300);
        simpleContract.setVote(1, address(0x2), 1, 100);
        simpleContract.setVote(1, address(0x3), 0, 300);
        simpleContract.setVote(1, address(0x4), 2, 600);

        assertTrue(simpleContract.voteSucceeded(1));
    }

    function testVoteDefeated() public {
        simpleContract.setVote(1, address(0x1), 1, 300);
        simpleContract.setVote(1, address(0x2), 0, 100);
        simpleContract.setVote(1, address(0x3), 0, 300);
        simpleContract.setVote(1, address(0x4), 2, 600);

        assertFalse(simpleContract.voteSucceeded(1));
    }

    function testCannotSpecifyInvalidWeightStrategy() public {
        vm.expectRevert("Governor: weighting strategy not found");
        TokenWeightStrategy.applyStrategy(100, bytes4(keccak256("blahdraticWeight(uint256)")));
    }
}
