// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./GovernorStorage.sol";

library GovernorProposalParams {
    /**
     * @dev Encodes the proposal params into a single bytes array.
     * @param token the token to use for voting.
     * @param weightingSelector the selector for the weighting function.
     * @return the encoded params.
     */
    function encodeProposalParams(address token, bytes4 weightingSelector) internal pure returns (bytes memory) {
        return abi.encode(token, weightingSelector);
    }

    /**
     * @dev Decodes the proposal params from a single bytes array.
     * @param params the encoded params.
     * @return token the token to use for voting.
     * @return weightingSelector the selector for the weighting function.
     */
    function decodeProposalParams(bytes storage params)
        internal
        pure
        returns (address token, bytes4 weightingSelector)
    {
        (token, weightingSelector) = abi.decode(params, (address, bytes4));
    }

    /**
     * @dev default proposal params for use in an implementing Governor's base call to super.propose.
     * @return the bytess for the default params.
     */
    function defaultProposalParams() internal pure returns (bytes memory) {
        return encodeProposalParams(address(0x0), bytes4(keccak256("simpleWeight(uint256)")));
    }

    /**
     * @dev A raw bytes array representation of the params for a given proposal.
     * @param proposalId The id of the proposal to get the params for.
     * @return the raw bytes of the params.
     */
    function getProposalParams(uint256 proposalId) internal view returns (bytes storage) {
        return GovernorStorage.proposal(proposalId).params;
    }

    /**
     * @dev A decoded representation of the params for a given proposal.
     * @param proposalId The id of the proposal to get the params for.
     * @return token the token to use for counting.
     * @return weightingSelector the strategy to use for counting.
     */
    function getDecodedProposalParams(uint256 proposalId)
        internal
        view
        returns (address token, bytes4 weightingSelector)
    {
        return decodeProposalParams(GovernorStorage.proposal(proposalId).params);
    }

    /**
     * @dev set the raw bytes array representation of the params for a given proposal.
     * @param proposalId The id of the proposal to set the params for.
     * @param params the raw bytes of the params.
     */
    function setProposalParams(uint256 proposalId, bytes memory params) internal {
        GovernorStorage.proposal(proposalId).params = params;
    }
}
