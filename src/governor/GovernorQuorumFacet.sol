// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IGovernorQuorum.sol";
import "./GovernorStorage.sol";
import "./libProposalParams.sol";
import "@oz/governance/utils/IVotes.sol";

contract GovernorQuorumFacet is IGovernorQuorum {
    /**
     * @dev Returns the current quorum numerator. See {quorumDenominator}.
     */
    function quorumNumerator() public view virtual returns (uint16) {
        return GovernorStorage.configStorage().quorumNumerator;
    }

    /**
     * @dev Returns the quorum numerator at a specific block number. See {quorumDenominator}.
     */
    function quorumNumerator(uint256 proposalId) public view virtual returns (uint16) {
        return GovernorStorage.proposal(proposalId).quorumNumerator;
    }

    /**
     * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
     */
    function quorumDenominator() public view virtual returns (uint16) {
        return 100;
    }

    /**
     * @dev Returns the quorum for a specific proposal's counting token at the given block number, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) public view virtual returns (uint256) {
        (address token,) = GovernorProposalParams.getDecodedProposalParams(proposalId);
        uint256 snapshot = GovernorStorage.proposal(proposalId).snapshot;
        uint256 supply = IVotes(token).getPastTotalSupply(snapshot);
        return (supply * quorumNumerator(proposalId)) / quorumDenominator();
    }

    /**
     * @dev Changes the quorum numerator.
     *
     * Emits a {QuorumNumeratorUpdated} event.
     *
     * Requirements:
     *
     * - Must be called through a governance proposal.
     * - New numerator must be smaller or equal to the denominator.
     */
    function updateQuorumNumerator(uint16 newQuorumNumerator) public virtual {
        require(
            newQuorumNumerator <= quorumDenominator(), "GovernorQuorumFacet: new numerator must be LTE the denominator"
        );
        GovernorStorage.configStorage().quorumNumerator = newQuorumNumerator;
        emit QuorumNumeratorUpdated(newQuorumNumerator);
    }
}
