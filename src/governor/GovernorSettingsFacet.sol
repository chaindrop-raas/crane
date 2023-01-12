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

    function defaultProposalToken() public view override returns (address) {
        return config().defaultProposalToken;
    }

    /**
     * @notice public interface to retrieve the configured governance token.
     * @return the governance token address.
     */
    function governanceToken() public view override returns (address) {
        return config().governanceToken;
    }

    /**
     * @notice public interface to retrieve the configured membership token.
     * @return the membership token address.
     */
    function membershipToken() public view override returns (address) {
        return config().membershipToken;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     */
    function proposalThreshold() public view returns (uint64) {
        return config().proposalThreshold;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold token.
     * @return the token address for the proposal threshold.
     */
    function proposalThresholdToken() public view returns (address) {
        return config().proposalThresholdToken;
    }

    /**
     * @notice public interface to retrieve the configured quorum numerator.
     * @return the quorum numerator for the proposal.
     */
    function quorumNumerator() public view returns (uint16) {
        return config().quorumNumerator;
    }

    /**
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     */
    function votingDelay() public view returns (uint24) {
        return config().votingDelay;
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     */
    function votingPeriod() public view returns (uint24) {
        return config().votingPeriod;
    }

    function setDefaultProposalToken(address newDefaultProposalToken) public onlyGovernance {
        GovernorStorage.setDefaultProposalToken(newDefaultProposalToken);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) public onlyGovernance {
        GovernorStorage.setGovernanceToken(newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) public onlyGovernance {
        GovernorStorage.setMembershipToken(newMembershipToken);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint24 newVotingDelay) public onlyGovernance {
        GovernorStorage.setVotingDelay(newVotingDelay);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) public onlyGovernance {
        GovernorStorage.setProposalThreshold(newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) public onlyGovernance {
        GovernorStorage.setProposalThresholdToken(newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint16 newQuorumNumerator) public onlyGovernance {
        GovernorStorage.setQuorumNumerator(newQuorumNumerator);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint24 newVotingPeriod) public onlyGovernance {
        GovernorStorage.setVotingPeriod(newVotingPeriod);
    }

    /**
     * @dev returns the GovernorConfig storage pointer.
     */
    function config() internal pure returns (GovernorStorage.GovernorConfig storage) {
        return GovernorStorage.configStorage();
    }

    /**
     * @dev restricts interaction to the timelock contract.
     */
    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }
}
