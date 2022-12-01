//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./GovernorWithProposalParams.sol";

abstract contract SimpleCounting is GovernorWithProposalParams {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    // proposalId => voter address => voteBytes
    mapping(uint256 => mapping(address => bytes)) private _proposalVote;
    // proposalId => voter addresses (provides index)
    mapping(uint256 => address[]) private _proposalVoters;
    // proposalId => voter address => true if voted
    mapping(uint256 => mapping(address => bool)) private _proposalHasVoted;

    /**
     * @notice module:reputation
     */
    function applyWeightStrategy(uint256 weight, bytes4 weightingSelector) public view returns (uint256) {
        // We check for success and only issue this as staticcall
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory data) = address(this).staticcall(abi.encodeWithSelector(weightingSelector, weight));
        if (success) {
            return abi.decode(data, (uint256));
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @dev See {IGovernor-_hasVoted}.
     * @notice module:voting
     * we differ from the base implementation in that we don't want to prevent
     * multiple votes, we instead update their previous vote.
     */
    function hasVoted(uint256 proposalId, address account) public view override returns (bool) {
        return _proposalHasVoted[proposalId][account];
    }

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     * @notice module:voting
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice module:reputation
     */
    function _countVote(uint256 proposalId, address account, uint8 support, uint256 weight, bytes memory)
        internal
        override (GovernorUpgradeable)
    {
        bytes memory vote;
        if (keccak256(_getProposalParamsBytes(proposalId)) == keccak256(_defaultParams())) {
            vote = abi.encode(VoteType(support), weight, weight);
        } else {
            (, bytes4 weightingSelector) = _getProposalParams(proposalId);
            vote = abi.encode(VoteType(support), weight, applyWeightStrategy(weight, weightingSelector));
        }
        _proposalVote[proposalId][account] = vote;
        _proposalVoters[proposalId].push(account);
        _proposalHasVoted[proposalId][account] = true;
    }

    /**
     * @notice module:voting
     */
    function _getProposalVoters(uint256 proposalId) internal view returns (address[] memory) {
        return _proposalVoters[proposalId];
    }

    /**
     * @notice module:voting
     */
    function _getVote(uint256 proposalId, address voter) internal view returns (VoteType, uint256, uint256) {
        return abi.decode(_proposalVote[proposalId][voter], (VoteType, uint256, uint256));
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
    //FIXME: if these aren't public, staticcall fails
    function simpleWeight(uint256 weight) public pure returns (uint256) {
        return weight;
    }

    /**
     * @notice module:reputation
     */
    //FIXME: if these aren't public, staticcall fails
    function quadraticWeight(uint256 weight) public pure returns (uint256) {
        return _squareRoot(weight);
    }
}
