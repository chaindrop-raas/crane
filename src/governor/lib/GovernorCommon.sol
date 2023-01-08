// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/GovernorStorage.sol";
import "./ProposalParams.sol";
import "./SimpleCounting.sol";
import "src/governor/IGovernor.sol";

library GovernorCommon {
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    function succededState(uint256 proposalId, IGovernor.ProposalState status) internal view returns (IGovernor.ProposalState) {
        if (status != IGovernor.ProposalState.Succeeded) {
            return status;
        }

        GovernorStorage.TimelockQueue storage queue = GovernorStorage.proposalStorage().timelockQueue[proposalId];
        GovernorStorage.ProposalCore storage proposal = GovernorStorage.proposalStorage().proposals[proposalId];
        if (queue.timestamp == 0) {
            return IGovernor.ProposalState.Succeeded;
        } else if (proposal.executed) {
            return IGovernor.ProposalState.Executed;
        } else if (proposal.canceled) {
            return IGovernor.ProposalState.Canceled;
        } else {
            return IGovernor.ProposalState.Queued;
        }
    }

    function state(uint256 proposalId) internal view returns (IGovernor.ProposalState) {
        GovernorStorage.ProposalCore storage proposal = GovernorStorage.proposalStorage().proposals[proposalId];

        if (proposal.executed) {
            return IGovernor.ProposalState.Executed;
        }

        if (proposal.canceled) {
            return IGovernor.ProposalState.Canceled;
        }

        if (proposal.snapshot == 0) {
            revert("Governor: unknown proposal id");
        }

        if (proposal.snapshot >= block.number) {
            return IGovernor.ProposalState.Pending;
        }

        if (proposal.deadline >= block.number) {
            return IGovernor.ProposalState.Active;
        }

        if (SimpleCounting.quorumReached(proposalId) && SimpleCounting.voteSucceeded(proposalId)) {
            return succededState(proposalId, IGovernor.ProposalState.Succeeded);
        } else {
            return IGovernor.ProposalState.Defeated;
        }
    }
}
