// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz/governance/utils/IVotes.sol";

library GovernorStorage {
    bytes32 public constant CONFIG_STORAGE_POSITION = keccak256("com.origami.governor.configStorage");
    bytes32 public constant PROPOSAL_STORAGE_POSITION = keccak256("com.origami.governor.proposalStorage");

    /**
     * Emitted when the default proposal token is set.
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

    function configStorage() internal pure returns (GovernorConfig storage gs) {
        bytes32 position = CONFIG_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            gs.slot := position
        }
    }

    function isConfiguredToken(address token) internal view returns (bool) {
        GovernorConfig storage cs = configStorage();
        return token == cs.membershipToken || token == cs.governanceToken;
    }

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

    function proposalStorage() internal pure returns (ProposalStorage storage ps) {
        bytes32 position = PROPOSAL_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            ps.slot := position
        }
    }

    function proposal(uint256 proposalId) internal view returns (ProposalCore storage) {
        return proposalStorage().proposals[proposalId];
    }

    function proposalVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return proposalStorage().proposalVote[proposalId][account];
    }

    function setProposalVote(uint256 proposalId, address account, bytes memory vote) internal {
        proposalStorage().proposalVote[proposalId][account] = vote;
    }

    function proposalVoters(uint256 proposalId) internal view returns (address[] storage) {
        return proposalStorage().proposalVoters[proposalId];
    }

    function proposalHasVoted(uint256 proposalId, address account) internal view returns (bool) {
        return proposalStorage().proposalHasVoted[proposalId][account];
    }

    function setProposalHasVoted(uint256 proposalId, address account, bool voted) internal {
        proposalStorage().proposalHasVoted[proposalId][account] = voted;
    }
}
