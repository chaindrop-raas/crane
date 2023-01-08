// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorSettings {
    /**
     * @dev Emitted when the voting delay is set.
     * @param oldVotingDelay The previous voting delay.
     * @param newVotingDelay The new voting delay.
     */
    event VotingDelaySet(uint24 oldVotingDelay, uint24 newVotingDelay);

    /**
     * @dev Emitted when the voting period is set.
     * @param oldVotingPeriod The previous voting period.
     * @param newVotingPeriod The new voting period.
     */
    event VotingPeriodSet(uint24 oldVotingPeriod, uint24 newVotingPeriod);

    /**
     * @dev Emitted when the proposal threshold is set.
     * @param oldProposalThreshold The previous proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     */
    event ProposalThresholdSet(uint64 oldProposalThreshold, uint64 newProposalThreshold);

    /**
     * @dev Emitted when the proposal threshold token is set.
     * @param oldProposalThresholdToken The previous proposal threshold.
     * @param newProposalThresholdToken The new proposal threshold.
     */
    event ProposalThresholdTokenSet(address oldProposalThresholdToken, address newProposalThresholdToken);

    /**
     * @dev Emitted when the quorum numerator is set.
     * @param oldQuorumNumerator The previous quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     */
    event QuorumNumeratorSet(uint16 oldQuorumNumerator, uint16 newQuorumNumerator);

    /**
     * @dev Returns the delay before voting on a proposal may take place, once proposed.
     */
    // TODO: change to seconds instead of blocks
    function votingDelay() external view returns (uint24);

    /**
     * @dev Returns the duration of voting on a proposal, in blocks.
     */
    //TODO: change to seconds instead of blocks
    function votingPeriod() external view returns (uint24);

    /**
     * @dev Returns the number of votes required in order for a voter to become a proposer.
     */
    function proposalThreshold() external view returns (uint64);

    /**
     * @dev Returns the token to use for proposal threshold.
     */
    function proposalThresholdToken() external view returns (address);

    /**
     * @dev Returns the quorum numerator for the proposal.
     */
    function quorumNumerator() external view returns (uint16);

    /**
     * @dev Sets the voting delay.
     * @param newVotingDelay The new voting delay.
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint24 newVotingDelay) external;

    /**
     * @dev Sets the voting period.
     * @param newVotingPeriod The new voting period.
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint24 newVotingPeriod) external;

    /**
     * @dev Sets the proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) external;

    /**
     * @dev Returns the token to use for proposal threshold.
     * Emits a {ProposalThresholdTokenSet} event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) external;

    /**
     * @dev Sets the quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     * Emits a {QuorumNumeratorSet} event.
     */
     function setQuorumNumerator(uint16 newQuorumNumerator) external;
}
