// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/interfaces/IGovernorSettings.sol";
import "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Settings Facet
 * @author Origami
 * @notice Logic for interacting with the Origami Governor configuration settings.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorSettingsFacet is IGovernorSettings {
    /**
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     */
    function votingDelay() public view returns (uint24) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingDelay;
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     */
    function votingPeriod() public view returns (uint24) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingPeriod;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     */
    function proposalThreshold() public view returns (uint64) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.proposalThreshold;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold token.
     * @return the token address for the proposal threshold.
     */
    function proposalThresholdToken() public view returns (address) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.proposalThresholdToken;
    }

    /**
     * @notice public interface to retrieve the configured quorum numerator.
     * @return the quorum numerator for the proposal.
     */
    function quorumNumerator() public view returns (uint16) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.quorumNumerator;
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     */
    function setVotingDelay(uint24 newVotingDelay) public onlyGovernance {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint24 oldVotingDelay = config.votingDelay;

        config.votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, newVotingDelay);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     */
    function setVotingPeriod(uint24 newVotingPeriod) public onlyGovernance {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint24 oldVotingPeriod = config.votingPeriod;

        config.votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     */
    function setProposalThreshold(uint64 newProposalThreshold) public onlyGovernance {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint64 oldProposalThreshold = config.proposalThreshold;

        config.proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) public onlyGovernance {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        address oldProposalThresholdToken = config.proposalThresholdToken;

        config.proposalThresholdToken = newProposalThresholdToken;

        emit ProposalThresholdTokenSet(oldProposalThresholdToken, newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     */
    function setQuorumNumerator(uint16 newQuorumNumerator) public onlyGovernance {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint16 oldQuorumNumerator = config.quorumNumerator;

        config.quorumNumerator = newQuorumNumerator;

        emit QuorumNumeratorSet(oldQuorumNumerator, newQuorumNumerator);
    }

    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }

}


