//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../GovernorQuorum.sol";
import "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact contract-security@joinorigami.com
 */
library SimpleCounting {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    bytes4 public constant simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
    bytes4 public constant quadraticWeightSelector = bytes4(keccak256("quadraticWeight(uint256)"));

    /**
     * @notice Applies the indicated weighting strategy to the amount `weight` that is supplied.
     * @dev the staticcall is only executed against this contract and is checked for success before failing to a revert if the selector isn't found on this contract.
     * @param weight the token weight to apply the weighting strategy to.
     * @param weightingSelector an encoded selector to use as a weighting strategy implementation.
     * @return the weight with the weighting strategy applied to it.
     */
    function applyWeightStrategy(uint256 weight, bytes4 weightingSelector) public pure returns (uint256) {
        // We check for success and only issue this as staticcall

        if (weightingSelector == simpleWeightSelector) {
            return simpleWeight(weight);
        } else if (weightingSelector == quadraticWeightSelector) {
            return quadraticWeight(weight);
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @notice a required function from IGovernor that declares what Governor style we support and how we derive quorum.
     * @dev See {IGovernor-COUNTING_MODE}.
     * @return string indicating the counting mode.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() external pure returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice simple weight calculation does not apply any weighting strategy. It is an integer identity function.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function simpleWeight(uint256 weight) public pure returns (uint256) {
        return weight;
    }

    /**
     * @notice quadratic weight calculation returns square root of the weight.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function quadraticWeight(uint256 weight) public pure returns (uint256) {
        return squareRoot(weight);
    }

    /**
     * @notice sets the vote for a given proposal and account in a manner that is compatible with SimpleCounting strategies.
     * @param proposalId the proposal to record the vote for
     * @param account the account that is voting
     * @param support the VoteType that the account is voting
     * @param weight the weight of their vote as of the proposal snapshot
     */
    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight) internal {
        bytes4 weightingSelector = GovernorStorage.proposal(proposalId).countingStrategy;

        bytes memory vote = abi.encode(VoteType(support), weight, applyWeightStrategy(weight, weightingSelector));
        GovernorStorage.setProposalVote(proposalId, account, vote);
        GovernorStorage.proposalVoters(proposalId).push(account);
        GovernorStorage.setProposalHasVoted(proposalId, account);
    }

    /**
     * @dev used by OrigamiGovernor when totaling proposal outcomes. We defer tallying so that individual voters can change their vote during the voting period.
     * @param proposalId the id of the proposal to retrieve voters for.
     * @return the list of voters for the proposal.
     */
    function getProposalVoters(uint256 proposalId) external view returns (address[] memory) {
        return GovernorStorage.proposalVoters(proposalId);
    }

    /**
     * @dev decodes the vote for a given proposal and voter.
     * @param proposalId the id of the proposal.
     * @param voter the address of the voter.
     * @return the vote type, the weight of the vote, and the weight of the vote with the weighting strategy applied.
     */
    function getVote(uint256 proposalId, address voter) public view returns (VoteType, uint256, uint256) {
        return abi.decode(GovernorStorage.proposalVote(proposalId, voter), (VoteType, uint256, uint256));
    }

    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     */
    function simpleProposalVotes(uint256 proposalId)
        public
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = GovernorStorage.proposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support,, uint256 calculatedWeight) = getVote(proposalId, voter);
            if (support == VoteType.Abstain) {
                abstainVotes += calculatedWeight;
            } else if (support == VoteType.For) {
                forVotes += calculatedWeight;
            } else if (support == VoteType.Against) {
                againstVotes += calculatedWeight;
            }
        }
    }

    /**
     * @dev implementation of {Governor-quorumReached} that is compatible with the SimpleCounting strategies.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the quorum has been reached.
     */
    function quorumReached(uint256 proposalId) external view returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = simpleProposalVotes(proposalId);
        bytes4 countingStrategy = GovernorStorage.proposal(proposalId).countingStrategy;
        return applyWeightStrategy(GovernorQuorum.quorum(proposalId), countingStrategy) <= forVotes + abstainVotes;
    }

    function voteSucceeded(uint256 proposalId) external view returns (bool) {
        (uint256 againstVotes, uint256 forVotes,) = simpleProposalVotes(proposalId);
        return forVotes > againstVotes;
    }

    /**
     * @dev square root algorithm from https://github.com/ethereum/dapp-bin/pull/50#issuecomment-1075267374
     * @param x the number to derive the square root of.
     * @return y - the square root of x.
     */
    function squareRoot(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
