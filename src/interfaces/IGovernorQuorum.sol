// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorQuorum {
    event QuorumNumeratorUpdated(uint16 quorumNumerator);

    /**
     * @dev Returns the current quorum numerator. See {quorumDenominator}.
     */
    function quorumNumerator() external view returns (uint16);

    /**
     * @dev Returns the quorum numerator at a specific block number. See {quorumDenominator}.
     */
    function quorumNumerator(uint256 blockNumber) external view returns (uint16);

    /**
     * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
     */
    function quorumDenominator() external view returns (uint16);

    /**
     * @dev Returns the quorum for a specific proposal's counting token at the given block number, in terms of number of votes: `supply * numerator / denominator`.
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
    function updateQuorumNumerator(uint16 newQuorumNumerator) external;
}
