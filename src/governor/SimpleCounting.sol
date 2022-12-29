//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./GovernorStorage.sol";
import "./libProposalParams.sol";

/// @title Simple Counting module
/// @author Stephen Caudill
/// @notice Builds upon GovernorWithProposalParams to implement swappable counting strategies at the proposal level.
/// @custom:security-contact contract-security@joinorigami.com
abstract contract SimpleCounting {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    /**
     * @notice Applies the indicated weighting strategy to the amount `weight` that is supplied.
     * @dev the staticcall is only executed against this contract and is checked for success before failing to a revert if the selector isn't found on this contract.
     * @param weight the token weight to apply the weighting strategy to.
     * @param weightingSelector an encoded selector to use as a weighting strategy implementation.
     * @return the weight with the weighting strategy applied to it.
     * module:reputation
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
     * @notice a required function from IGovernor that declares what Governor style we support and how we derive quorum.
     * @dev See {IGovernor-COUNTING_MODE}.
     * @return string indicating the counting mode.
     * module:voting
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice simple weight calculation does not apply any weighting strategy. It is an integer identity function.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     * module:reputation
     */
    function simpleWeight(uint256 weight) public pure returns (uint256) {
        return weight;
    }

    /**
     * @notice quadratic weight calculation returns square root of the weight.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     * module:reputation
     */
    function quadraticWeight(uint256 weight) public pure returns (uint256) {
        return squareRoot(weight);
    }

    /**
     * @dev a version of _countVote that is compatible with the GovernorWithProposalParams implementation.
     * @param proposalId the proposal to record the vote for
     * @param account the account that is voting
     * @param support the VoteType that the account is voting
     * @param weight the weight of their vote as of the proposal snapshot
     * module:reputation
     */
    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight, bytes memory)
        internal
    {
        bytes memory vote;
        bytes storage proposalParams = GovernorProposalParams.getProposalParams(proposalId);
        // _defaultParams() from the OZ lib uses "" as the default value, so we
        // check for that here and encode without a weighting strategy if so.
        if (keccak256(proposalParams) == keccak256("")) {
            vote = abi.encode(VoteType(support), weight, weight);
        } else {
            (, bytes4 weightingSelector) = GovernorProposalParams.decodeProposalParams(proposalParams);
            vote = abi.encode(VoteType(support), weight, applyWeightStrategy(weight, weightingSelector));
        }
        GovernorStorage.setProposalVote(proposalId, account, vote);
        GovernorStorage.proposalVoters(proposalId).push(account);
        GovernorStorage.setProposalHasVoted(proposalId, account, true);
    }

    /**
     * @dev used by OrigamiGovernor when totaling proposal outcomes. We defer tallying so that individual voters can change their vote during the voting period.
     * @param proposalId the id of the proposal to retrieve voters for.
     * @return the list of voters for the proposal.
     * module:voting
     */
    function getProposalVoters(uint256 proposalId) internal view returns (address[] memory) {
        return GovernorStorage.proposalVoters(proposalId);
    }

    /**
     * @dev decodes the vote for a given proposal and voter.
     * @param proposalId the id of the proposal.
     * @param voter the address of the voter.
     * @return the vote type, the weight of the vote, and the weight of the vote with the weighting strategy applied.
     * module:voting
     */
    function getVote(uint256 proposalId, address voter) internal view returns (VoteType, uint256, uint256) {
        return abi.decode(GovernorStorage.proposalVote(proposalId, voter), (VoteType, uint256, uint256));
    }

    /**
     * @dev square root algorithm from https://github.com/ethereum/dapp-bin/pull/50#issuecomment-1075267374
     * @param x the number to derive the square root of.
     * @return y - the square root of x.
     */
    function squareRoot(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
