// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz/governance/utils/IVotes.sol";

library GovernorStorage {
    bytes32 public constant CONFIG_STORAGE_POSITION = keccak256("com.origami.governor.configStorage");
    bytes32 public constant PROPOSAL_STORAGE_POSITION = keccak256("com.origami.governor.proposalStorage");

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
        address membershipToken;
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
