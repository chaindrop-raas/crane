// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/interfaces/IGovernor.sol";
import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

contract SettingsFacetTest is GovernorDiamondHelper {
    function testInformationalFunctions() public {
        assertEq(settingsFacet.votingDelay(), 604_800);
        assertEq(settingsFacet.votingPeriod(), 604_800);
        assertEq(settingsFacet.proposalThreshold(), 1);
        assertEq(settingsFacet.quorumNumerator(), 10);
    }

    function testRetrieveProposalThreshold() public {
        assertEq(settingsFacet.proposalThreshold(), 1);
    }

    function testCannotDirectlyUpdateGovernanceToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setGovernanceToken(address(0));
    }

    function testCannotDirectlyUpdateMembershipToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setMembershipToken(address(0));
    }

    function testCannotDirectlyUpdateProposalThreshold() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThreshold(0);
    }

    function testCannotDirectlyUpdateProposalThresholdToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThresholdToken(address(0));
    }

    function testCannotDirectlyUpdateQuorumNumerator() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setQuorumNumerator(0);
    }

    function testCannotDirectlyUpdateVotingDelay() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingDelay(0);
    }

    function testCannotDirectlyUpdateVotingPeriod() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingPeriod(0);
    }

    function testTimelockCanUpdateGovernanceToken() public {
        vm.prank(address(timelock));
        settingsFacet.setGovernanceToken(address(0xbeef));
    }

    function testTimelockCanUpdateMembershipToken() public {
        vm.prank(address(timelock));
        settingsFacet.setMembershipToken(address(0xbeef));
    }

    function testTimelockCanUpdateProposalThreshold() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThreshold(0);
    }

    function testTimelockCanUpdateProposalThresholdToken() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThresholdToken(address(0xbeef));
    }

    function testTimelockCanUpdateQuorumNumerator() public {
        vm.prank(address(timelock));
        settingsFacet.setQuorumNumerator(0);
    }

    function testTimelockCanUpdateVotingDelay() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingDelay(0);
    }

    function testTimelockCanUpdateVotingPeriod() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingPeriod(0);
    }
}

contract OrigamiGovernorUpdateSettingsViaProposal is GovernorDiamondHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;
    address public newGovToken;

    function setUp() public {
        newGovToken = address(0xBadBeef);
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("setGovernanceToken(address)", newGovToken);

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testUpdateGovernanceTokenViaProposal() public {
        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), address(govToken));

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // advance to the voting period
        vm.roll(604_843);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(604_843 + 604_800);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // the TimelockController cares about the block timestamp, so we need to warp in addition to roll
        // advance block timestamp so that it's after the proposal's required queuing time
        vm.warp(604_801);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        // advance past the execution delay
        vm.roll(604_843 + 604_801);

        // proposal is in the executed state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), newGovToken);
    }
}
