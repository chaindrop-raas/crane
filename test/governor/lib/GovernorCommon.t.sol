// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import "src/governor/lib/GovernorCommon.sol";

contract CommonContract is GovernorDiamondHelper {
    constructor() {
        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        cs.votingDelay = 1 days;
        cs.votingPeriod = 2 days;
        cs.quorumNumerator = 1;
        cs.proposalThresholdToken = address(govToken);
        cs.proposalThreshold = 100;
    }

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
    }

    function createProposal(uint256 proposalId) public {
        GovernorStorage.createProposal(proposalId, address(govToken), TokenWeightStrategy.simpleWeightSelector);
    }

    function proposal(uint256 id) public view returns (GovernorStorage.ProposalCore memory) {
        return GovernorStorage.proposal(id);
    }

    function cancel(uint256 proposalId) public {
        GovernorStorage.proposal(proposalId).canceled = true;
    }

    function execute(uint256 proposalId) public {
        GovernorStorage.proposal(proposalId).executed = true;
    }

    function state(uint256 proposalId) public view returns (IGovernor.ProposalState) {
        return GovernorCommon.state(proposalId);
    }

    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight) public {
        SimpleCounting.setVote(proposalId, account, support, weight);
    }
}

contract CommonContractTest is GovernorDiamondHelper {
    CommonContract public commonContract;

    function setUp() public {
        commonContract = new CommonContract();
        commonContract.createProposal(1);
    }

    function testHashProposal() public {
        assertEq(
            commonContract.hashProposal(new address[](0), new uint256[](0), new bytes[](0), bytes32(0)),
            uint256(keccak256(abi.encode(new address[](0), new uint256[](0), new bytes[](0), bytes32(0))))
        );
    }

    function testStateInvalidProposal() public {
        vm.expectRevert("Governor: unknown proposal id");
        commonContract.state(42);
    }

    function testStatePending() public {
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Pending));
    }

    function testStateActive() public {
        vm.warp(block.timestamp + 1 days + 1);
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Active));
    }

    function testStateCanceled() public {
        commonContract.cancel(1);
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Canceled));
    }

    function testStateExecuted() public {
        commonContract.execute(1);
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Executed));
    }

    function testStateDefeated() public {
        vm.warp(block.timestamp + 7 days + 1);
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testStateSucceeded() public {
        vm.prank(voter4);
        commonContract.setVote(1, voter4, 1, 306250000);
        vm.warp(block.timestamp + 7 days + 1);
        assertEq(uint8(commonContract.state(1)), uint8(IGovernor.ProposalState.Succeeded));
    }
}
