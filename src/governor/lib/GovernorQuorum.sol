// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IVotes} from "src/interfaces/IVotes.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Quorum shared functions
 * @author Origami
 * @custom:security-contact contract-security@joinorigami.com
 */
library GovernorQuorum {
    /**
     * @dev Returns the quorum numerator for a specific proposalId. This value is set from global config at the time of proposal creation.
     */
    function quorumNumerator(uint256 proposalId) internal view returns (uint128) {
        return GovernorStorage.proposal(proposalId).quorumNumerator;
    }

    /**
     * @dev Returns the quorum denominator. Typically set to 100, but is configurable.
     */
    function quorumDenominator(uint256 proposalId) internal view returns (uint128) {
        return GovernorStorage.proposal(proposalId).quorumDenominator;
    }

    /**
     * @dev Returns the quorum for a specific proposal's counting token as of its time of creation, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) internal view returns (uint256) {
        address proposalToken = GovernorStorage.proposal(proposalId).proposalToken;
        uint256 snapshot = GovernorStorage.proposal(proposalId).snapshot;
        uint256 supply = IVotes(proposalToken).getPastTotalSupply(snapshot);
        return (supply * quorumNumerator(proposalId)) / quorumDenominator(proposalId);
    }
}
