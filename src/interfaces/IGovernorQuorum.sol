// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorQuorum {
    event QuorumNumeratorUpdated(uint128 quorumNumerator);

    /**
     * @dev Returns the current quorum numerator. See {quorumDenominator}.
     */
    function quorumNumerator() external view returns (uint128);

    /**
     * @dev Returns the quorum numerator for a specific proposalId.
     */
    function quorumNumerator(uint256 proposalId) external view returns (uint128);

    /**
     * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
     */
    function quorumDenominator() external view returns (uint128);

    /**
     * @dev Returns the quorum for a specific proposal's counting token, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) external view returns (uint256);

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
    function updateQuorumNumerator(uint128 newQuorumNumerator) external;
}
