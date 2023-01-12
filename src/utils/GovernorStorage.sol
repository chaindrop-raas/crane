// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz/governance/utils/IVotes.sol";

library GovernorStorage {
    bytes32 public constant CONFIG_STORAGE_POSITION = keccak256("com.origami.governor.configStorage");
    bytes32 public constant PROPOSAL_STORAGE_POSITION = keccak256("com.origami.governor.proposalStorage");

    /**
     * @dev Emitted when the default counting strategy is set.
     * @param oldDefaultCountingStrategy The previous default counting strategy.
     * @param newDefaultCountingStrategy The new default counting strategy.
     */
    event DefaultCountingStrategySet(bytes4 oldDefaultCountingStrategy, bytes4 newDefaultCountingStrategy);

    /**
     * @dev Emitted when the default proposal token is set.
     * @param oldDefaultProposalToken The previous default proposal token.
     * @param newDefaultProposalToken The new default proposal token.
     */
    event DefaultProposalTokenSet(address oldDefaultProposalToken, address newDefaultProposalToken);

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
     * @dev Emitted when the membership token is set.
     * @param oldMembershipToken The previous membership token.
     * @param newMembershipToken The new membership token.
     */
    event MembershipTokenSet(address oldMembershipToken, address newMembershipToken);

    /**
     * @dev Emitted when the governance token is set.
     * @param oldGovernanceToken The previous governance token.
     * @param newGovernanceToken The new governance token.
     */
    event GovernanceTokenSet(address oldGovernanceToken, address newGovernanceToken);

    struct ProposalCore {
        address proposalToken;
        bytes4 countingStrategy;
        uint16 quorumNumerator;
        uint64 snapshot;
        uint64 deadline;
        bytes params;
        bool canceled;
        bool executed;
    }

    struct GovernorConfig {
        string name;
        address admin;
        address payable timelock;
        address defaultProposalToken;
        bytes4 defaultCountingStrategy;
        address membershipToken;
        address governanceToken;
        address proposalThresholdToken;
        // TODO: consider these uint sizes carefully
        uint24 votingDelay;
        uint24 votingPeriod;
        uint16 quorumNumerator;
        // specifically, this seems like it might be too small to denote quantity in wei
        uint64 proposalThreshold;
    }

    struct TimelockQueue {
        uint256 timestamp;
    }

    struct ProposalStorage {
        // proposalId => ProposalCore
        mapping(uint256 => ProposalCore) proposals;
        // proposalId => voter address => voteBytes
        mapping(uint256 => mapping(address => bytes)) proposalVote;
        // proposalId => voter addresses (provides index)
        mapping(uint256 => address[]) proposalVoters;
        // proposalId => voter address => true if voted
        mapping(uint256 => mapping(address => bool)) proposalHasVoted;
        // proposalId => TimelockQueue
        mapping(uint256 => TimelockQueue) timelockQueue;
        // voter address => nonce
        mapping(address => uint256) nonces;
    }

    /**
     * @dev returns the ConfigStorage location.
     */
    function configStorage() internal pure returns (GovernorConfig storage gs) {
        bytes32 position = CONFIG_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            gs.slot := position
        }
    }

    /**
     * @dev determines if the provided token is the membership token or
     *  governance token. This is useful to ensure that functions that allow
     *  specifying a token address can't use unexpected tokens.
     * @param token the token address to check.
     * @return true if the token is the membership token or governance token.
     */
    function isConfiguredToken(address token) internal view returns (bool) {
        GovernorConfig storage cs = configStorage();
        return token == cs.membershipToken || token == cs.governanceToken;
    }

    /**
     * @notice sets the default counting strategy.
     * @param newDefaultCountingStrategy the new default counting strategy address.
     * emits DefaultCountingStrategySet event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) internal {
        bytes4 oldDefaultCountingStrategy = configStorage().defaultCountingStrategy;
        configStorage().defaultCountingStrategy = newDefaultCountingStrategy;

        emit DefaultCountingStrategySet(oldDefaultCountingStrategy, newDefaultCountingStrategy);
    }

    /**
     * @notice sets the default proposal token.
     * @param newDefaultProposalToken the new default proposal token address.
     * emits DefaultProposalTokenSet event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) internal {
        address oldDefaultProposalToken = configStorage().defaultProposalToken;
        configStorage().defaultProposalToken = newDefaultProposalToken;

        emit DefaultProposalTokenSet(oldDefaultProposalToken, newDefaultProposalToken);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) internal {
        address oldGovernanceToken = configStorage().governanceToken;
        configStorage().governanceToken = newGovernanceToken;

        emit GovernanceTokenSet(oldGovernanceToken, newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) internal {
        address oldMembershipToken = configStorage().membershipToken;
        configStorage().membershipToken = newMembershipToken;

        emit MembershipTokenSet(oldMembershipToken, newMembershipToken);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) internal {
        uint64 oldProposalThreshold = configStorage().proposalThreshold;
        configStorage().proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) internal {
        address oldProposalThresholdToken = configStorage().proposalThresholdToken;
        configStorage().proposalThresholdToken = newProposalThresholdToken;

        emit ProposalThresholdTokenSet(oldProposalThresholdToken, newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint16 newQuorumNumerator) internal {
        uint16 oldQuorumNumerator = configStorage().quorumNumerator;
        configStorage().quorumNumerator = newQuorumNumerator;

        emit QuorumNumeratorSet(oldQuorumNumerator, newQuorumNumerator);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint24 newVotingDelay) internal {
        uint24 oldVotingDelay = configStorage().votingDelay;
        configStorage().votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, newVotingDelay);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint24 newVotingPeriod) internal {
        uint24 oldVotingPeriod = configStorage().votingPeriod;
        configStorage().votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
    }

    /**
     * @dev returns the ProposalStorage location.
     */
    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            ps.slot := position
        }
    }

    /**
     * @notice creates a new proposal.
     * @param proposalId the proposal id.
     * @param proposalToken the proposal token.
     * @param countingStrategy the counting strategy.
     * @return ps the proposal core storage.
     */
    function createProposal(uint256 proposalId, address proposalToken, bytes4 countingStrategy)
        internal
        returns (ProposalCore storage ps)
    {
        // start populating the new ProposalCore struct
        ps = proposal(proposalId);
        GovernorConfig storage cs = configStorage();

        require(ps.snapshot == 0, "Governor: proposal already exists");

        ps.proposalToken = proposalToken;
        ps.countingStrategy = countingStrategy;
        ps.quorumNumerator = cs.quorumNumerator;
        // TODO: circle back and factor away from block.number and to
        // block.timestamp so we can deploy to chains like Optimism.
        // --
        // An epoch exceeding max UINT64 is 584,942,417,355 years from now. I
        // feel pretty safe casting this.
        ps.snapshot = uint64(block.number) + cs.votingDelay;
        ps.deadline = ps.snapshot + cs.votingPeriod;

        return ps;
    }

    /**
     * @notice returns the proposal core storage.
     * @param proposalId the proposal id.
     * @return ps the proposal core storage.
     */
    function proposal(uint256 proposalId) internal view returns (ProposalCore storage) {
        return proposalStorage().proposals[proposalId];
    }

    /**
     * @notice returns the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return the bytes representation of the vote
     */
    function proposalVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return proposalStorage().proposalVote[proposalId][account];
    }

    /**
     * @notice sets the vote for an account on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @param vote the bytes representation of the vote
     */
    function setProposalVote(uint256 proposalId, address account, bytes memory vote) internal {
        proposalStorage().proposalVote[proposalId][account] = vote;
    }

    /**
     * @notice returns the list of voters for a particular proposal.
     * @param proposalId the proposal id.
     * @return the list of voters.
     */
    function proposalVoters(uint256 proposalId) internal view returns (address[] storage) {
        return proposalStorage().proposalVoters[proposalId];
    }

    /**
     * @notice returns whether an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     * @return true if the account has voted on the proposal.
     */
    function proposalHasVoted(uint256 proposalId, address account) internal view returns (bool) {
        return proposalStorage().proposalHasVoted[proposalId][account];
    }

    /**
     * @notice call to indicate that an account has voted on a particular proposal.
     * @param proposalId the proposal id.
     * @param account the account.
     */
    function setProposalHasVoted(uint256 proposalId, address account) internal {
        proposalStorage().proposalHasVoted[proposalId][account] = true;
    }
}
