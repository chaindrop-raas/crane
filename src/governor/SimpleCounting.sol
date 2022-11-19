//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "src/GovernorWithProposalParams.sol";

abstract contract SimpleCounting is GovernorWithProposalParams {
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

    struct ProposalVote {
        VoteType support;
        uint256 weight;
    }

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice module:voting
     */
    function encodeVote(VoteType support, uint256 weight)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(support, weight);
    }

    /**
     * @notice module:voting
     */
    function decodeVote(bytes memory vote)
        public
        pure
        returns (VoteType support, uint256 weight)
    {
        return abi.decode(vote, (VoteType, uint256));
    }

    /**
     * @notice module:voting
     */
    function proposalVoters(uint256 proposalId)
        internal
        view
        returns (address[] memory)
    {
        return _proposalVoters[proposalId];
    }

    /**
     * @notice module:voting
     */
    function proposalByteVotes(uint256 proposalId, address voter)
        internal
        view
        returns (bytes memory)
    {
        return _proposalByteVotes[proposalId][voter];
    }

    /**
     * @notice module:reputation
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory
    ) internal override (GovernorUpgradeable) {
        bytes memory vote = encodeVote(VoteType(support), weight);
        _proposalByteVotes[proposalId][account] = vote;
        _proposalVoters[proposalId].push(account);
        _proposalHasVoted[proposalId][account] = true;
    }


    function _squareRoot(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @notice module:reputation
     */
    function _simpleWeight(uint256 weight) private pure returns (uint256) {
        return weight;
    }

    /**
     * @notice module:reputation
     */
    function _quadraticWeight(uint256 weight) private pure returns (uint256) {
        return _squareRoot(weight);
    }

    /**
     * @notice module:reputation
     */
    function applyWeightStrategy(uint256 weight, bytes4 weightingSelector)
        public
        view
        returns (uint256)
    {
        (bool success, bytes memory data) = address(this).staticcall(
            abi.encodeWithSelector(weightingSelector, weight)
        );
        if(success) {
            return abi.decode(data, (uint256));
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @dev See {IGovernor-_hasVote}.
     * we differ from the base implementation in that we don't want to prevent
     * multiple votes, we instead update their previous vote.
     */
    function hasVoted(uint256 proposalId, address account)
        public
        view
        override
        returns (bool)
    {
        return _proposalHasVoted[proposalId][account];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
