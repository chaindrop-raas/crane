//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/GovernorStorage.sol";

/**
 * @title Core voting interface
 * @author Origami
 * @custom:security-contact contract-security@joinorigami.com
 */
library Voting {
    function setVote(uint256 proposalId, address account, bytes memory vote) internal {
        GovernorStorage.setProposalVote(proposalId, account, vote);
        GovernorStorage.proposalVoters(proposalId).push(account);
        GovernorStorage.setProposalHasVoted(proposalId, account);
    }

    function getVote(uint256 proposalId, address account) internal view returns (bytes memory) {
        return GovernorStorage.proposalVote(proposalId, account);
    }
}
