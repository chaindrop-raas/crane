// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/lib/SimpleCounting.sol";
import "src/interfaces/IGovernor.sol";
import "src/utils/GovernorStorage.sol";

/**
 * @author Origami
 * @dev Common functions for the Governor modules.
 * @custom:security-contact contract-security@joinorigami.com
 */
library GovernorCommon {
    /**
     * @notice generates the hash of a proposal
     * @param targets the targets of the proposal
     * @param values the values of the proposal
     * @param calldatas the calldatas of the proposal
     * @param descriptionHash the hash of the description of the proposal
     * @return the hash of the proposal, used as an id
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /**
     * @notice execution state for a proposal, intended for use on successful proposals
     * @param proposalId the id of the proposal
     * @param status the current status of the proposal
     * @return the execution state of the proposal else the current status
     */
    function succededState(uint256 proposalId, IGovernor.ProposalState status)
        internal
        view
        returns (IGovernor.ProposalState)
    {
        if (status != IGovernor.ProposalState.Succeeded) {
            return status;
        }

        GovernorStorage.TimelockQueue storage queue = GovernorStorage.proposalStorage().timelockQueue[proposalId];
        if (queue.timestamp == 0) {
            return IGovernor.ProposalState.Succeeded;
        } else {
            return IGovernor.ProposalState.Queued;
        }
    }

    function state(uint256 proposalId) internal view returns (IGovernor.ProposalState) {
        GovernorStorage.ProposalCore storage proposal = GovernorStorage.proposal(proposalId);

        if (proposal.executed) {
            return IGovernor.ProposalState.Executed;
        }

        if (proposal.canceled) {
            return IGovernor.ProposalState.Canceled;
        }

        if (proposal.snapshot == 0) {
            // coverage seems convinced this is not invoked, but we have a test that proves it is
            revert("Governor: unknown proposal id");
        }

        if (proposal.snapshot >= block.timestamp) {
            return IGovernor.ProposalState.Pending;
        }

        if (proposal.deadline >= block.timestamp) {
            return IGovernor.ProposalState.Active;
        }

        if (SimpleCounting.quorumReached(proposalId) && SimpleCounting.voteSucceeded(proposalId)) {
            return succededState(proposalId, IGovernor.ProposalState.Succeeded);
        } else {
            return IGovernor.ProposalState.Defeated;
        }
    }
}
