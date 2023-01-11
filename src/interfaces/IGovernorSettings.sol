// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorSettings {

    /**
     * @dev Returns the governance token address.
     */
    function governanceToken() external view returns (address);

    /**
     * @dev Returns the membership token address.
     */
    function membershipToken() external view returns (address);

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
     * @dev Sets the governance token.
     * @param newGovernanceToken The new governance token.
     * Emits a {GovernanceTokenSet} event.
     */
    function setGovernanceToken(address newGovernanceToken) external;

    /**
     * @dev Sets the membership token.
     * @param newMembershipToken The new membership token.
     * Emits a {MembershipTokenSet} event.
     */
    function setMembershipToken(address newMembershipToken) external;

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

}
