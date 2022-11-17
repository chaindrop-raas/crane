//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ICounting.sol";
import "@oz-upgradeable/governance/GovernorUpgradeable.sol";

abstract contract SimpleCounting is ICounting, GovernorUpgradeable {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    // proposalId => voter address => voteBytes
    mapping(uint256 => mapping(address => bytes)) private _proposalByteVotes;
    // proposalId => voter addresses (provides index)
    mapping(uint256 => address[]) private _proposalVoters;
    // proposalId => voter address => true if voted
    mapping(uint256 => mapping(address => bool)) private _proposalHasVoted;

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    struct ProposalVote {
        VoteType support;
        uint256 weight;
    }

    function encodeVote(VoteType support, uint256 weight)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(support, weight);
    }

    function decodeVote(bytes memory vote)
        public
        pure
        returns (VoteType support, uint256 weight)
    {
        return abi.decode(vote, (VoteType, uint256));
    }

    function countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory
    ) public returns (uint256) {
        bytes memory vote = encodeVote(VoteType(support), weight);
        _proposalByteVotes[proposalId][account] = vote;
        _proposalVoters[proposalId].push(account);
        _proposalHasVoted[proposalId][account] = true;
        return weight;
    }

    function proposalVotes(uint256 proposalId)
        public
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = _proposalVoters[proposalId];
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            bytes memory vote = _proposalByteVotes[proposalId][voter];
            (VoteType support, uint256 weight) = decodeVote(vote);
            if (support == VoteType.Abstain) {
                abstainVotes += weight;
            } else if (support == VoteType.For) {
                forVotes += weight;
            } else if (support == VoteType.Against) {
                againstVotes += weight;
            }
        }
    }

    function hasVoted(uint256 proposalId, address account)
        public
        view
        override
        returns (bool)
    {
        return _proposalHasVoted[proposalId][account];
    }

    /**
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        (, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);

        return quorum(proposalSnapshot(proposalId)) <= forVotes + abstainVotes;
    }

    /**
     * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);

        return forVotes > againstVotes;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
