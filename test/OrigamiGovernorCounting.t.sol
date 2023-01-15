// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import { GovernorDiamondHelper } from "test/OrigamiDiamondTestHelper.sol";

import "src/governor/lib/TokenWeightStrategy.sol";
import "src/interfaces/IGovernor.sol";

contract OrigamiGovernorSimpleCounting is GovernorDiamondHelper {
    function testCannotSpecifyInvalidWeightStrategy() public {
        vm.expectRevert("Governor: weighting strategy not found");
        TokenWeightStrategy.applyStrategy(100, bytes4(keccak256("blahdraticWeight(uint256)")));
    }
}

contract OrigamiGovernorProposalQuadraticVoteTest is GovernorDiamondHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithQuadraticCounting() public {
        // self-delegate to get voting power
        vm.startPrank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it!");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it!");
    }
}

contract OrigamiGovernorProposalQuadraticVoteResultsTest is GovernorDiamondHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Quadratic Proposal", params);
    }

    function testQuadraticVotingResultsAreCorrect() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // set block to first eligible voting block
        vm.roll(604_843);

        // voter and voter2 collectively have fewer tokens than voter3 by
        // themselves, but quadratic weighting has the effect of making them
        // more powerful together than voter3 alone

        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it!");

        vm.prank(voter2);
        coreFacet.castVoteWithReason(proposalId, AGAINST, "This is rubbish!");

        vm.prank(voter3);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it too! It's not rubbish at all!");

        vm.prank(voter4);
        coreFacet.castVoteWithReason(proposalId, ABSTAIN, "I have no opinion.");

        vm.roll(640_483 + 604_800);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = coreFacet.proposalVotes(proposalId);

        assertEq(againstVotes, 15000);
        assertEq(forVotes, 17500);
        assertEq(abstainVotes, 17500);
    }
}
