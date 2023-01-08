// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/interfaces/IGovernorSettings.sol";
import "src/utils/GovernorStorage.sol";

/**
 * @dev Extension of {Governor} for settings updatable through governance.
 *
 * _Available since v4.4._
 */
contract GovernorSettingsFacet is IGovernorSettings {
    /**
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     * module:core
     */
    function votingDelay() public view returns (uint24) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingDelay;
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     * module:core
     */
    function votingPeriod() public view returns (uint24) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingPeriod;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     * module:core
     */
    function proposalThreshold() public view returns (uint64) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.proposalThreshold;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold token.
     * @return the token address for the proposal threshold.
     * module:core
     */
    function proposalThresholdToken() public view returns (address) {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.proposalThresholdToken;
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * module:core
     */
    function setVotingDelay(uint24 newVotingDelay) public {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint24 oldVotingDelay = config.votingDelay;

        config.votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, newVotingDelay);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * module:core
     */
    function setVotingPeriod(uint24 newVotingPeriod) public {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint24 oldVotingPeriod = config.votingPeriod;

        config.votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * module:core
     */
    function setProposalThreshold(uint64 newProposalThreshold) public {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        uint64 oldProposalThreshold = config.proposalThreshold;

        config.proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * module:core
     */
    function setProposalThresholdToken(address newProposalThresholdToken) public {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        address oldProposalThresholdToken = config.proposalThresholdToken;

        config.proposalThresholdToken = newProposalThresholdToken;

        emit ProposalThresholdTokenSet(oldProposalThresholdToken, newProposalThresholdToken);
    }


}


