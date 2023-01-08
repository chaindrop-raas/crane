// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/GovernorStorage.sol";

import "@oz-upgradeable/governance/GovernorUpgradeable.sol";
import "@oz/governance/utils/IVotes.sol";
import "@oz/utils/introspection/ERC165.sol";

/// @title Governor With Proposal Params
/// @author Stephen Caudill
/// @notice This contract extends the Governor interface to support changing the counting strategy on a per-proposal basis.
/// @dev we use OZ GovernorUpgradeable as the base contract solely so we can super.propose() in our custom propose function.
/// @custom:security-contact contract-security@joinorigami.com
abstract contract GovernorWithProposalParams is GovernorUpgradeable {
    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy.
     * @dev See {GovernorUpgradeable-_propose}.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param params the encoded bytes that specify the proposal's counting strategy and the token to use for counting.
     * @return proposalId The id of the newly created proposal.
     * module:proposal-params
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) public returns (uint256 proposalId) {
        if (keccak256(params) == keccak256(_defaultProposalParams())) {
            return super.propose(targets, values, calldatas, description);
        }
        (address proposalToken,) = hydrateParams(params);
        require(
            ERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );

        proposalId = super.propose(targets, values, calldatas, description);

        // start populating the new ProposalCore struct
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        ps.params = params;
        ps.quorumNumerator = GovernorStorage.configStorage().quorumNumerator;
        // TODO: circle back and factor away from block.number and to
        // block.timestamp so we can deploy to chains like Optimism.
        // --
        // An epoch exceeding max UINT64 is 584,942,417,355 years from now. I
        // feel pretty safe casting this.
        ps.snapshot = uint64(block.number) + GovernorStorage.configStorage().votingDelay;
        ps.deadline = ps.snapshot + GovernorStorage.configStorage().votingPeriod;
    }

    /**
     * @notice A raw byte representation of the params for a given proposal.
     * @dev This is primarily useful for comparing with the default params.
     * @param proposalId The id of the proposal to get the params for.
     * @return the raw bytes of the params.
     * module:proposal-params
     */
    function getProposalParamsBytes(uint256 proposalId) internal view returns (bytes memory) {
        return GovernorStorage.proposal(proposalId).params;
    }

    /**
     * @notice A decoded representation of the params for a given proposal.
     * @param proposalId The id of the proposal to get the params for.
     * @return token the token to use for counting.
     * @return weightingSelector the strategy to use for counting.
     * module:proposal-params
     */
    function getProposalParams(uint256 proposalId) internal view returns (address token, bytes4 weightingSelector) {
        return hydrateParams(GovernorStorage.proposal(proposalId).params);
    }

    /**
     * @dev default proposal params for use in an implementing Governor's base call to super.propose.
     * @return the bytess for the default params.
     * module:proposal-params
     */
    function _defaultProposalParams() internal pure virtual returns (bytes memory) {
        return abi.encode(address(0x0), bytes4(keccak256("simpleWeight(uint256)")));
    }

    /**
     * @notice Decode the params for a given proposal.
     * @param params the raw bytes of the params.
     * @return token the token to use for counting.
     * @return weightingSelector the strategy to use for counting.
     * module:proposal-params
     */
    function hydrateParams(bytes memory params) internal pure returns (address token, bytes4 weightingSelector) {
        (token, weightingSelector) = abi.decode(params, (address, bytes4));
    }
}
