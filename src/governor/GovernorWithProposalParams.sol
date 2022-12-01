// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz-upgradeable/governance/GovernorUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz/governance/utils/IVotes.sol";
import "@oz/utils/introspection/ERC165.sol";

abstract contract GovernorWithProposalParams is Initializable, GovernorUpgradeable {
    mapping(uint256 => bytes) private _proposalParams;

    /**
     * @notice module:proposal-params
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) public returns (uint256) {
        if (keccak256(params) == keccak256(_defaultProposalParams())) {
            return super.propose(targets, values, calldatas, description);
        }
        (address proposalToken,) = _hydrateParams(params);
        require(
            ERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );

        uint256 proposalId = super.propose(targets, values, calldatas, description);

        _proposalParams[proposalId] = params;

        return proposalId;
    }

    /**
     * @notice module:proposal-params
     */
    function _getProposalParamsBytes(uint256 proposalId) internal view returns (bytes memory) {
        return _proposalParams[proposalId];
    }

    /**
     * @notice module:proposal-params
     */
    function _getProposalParams(uint256 proposalId) internal view returns (address token, bytes4 weightingSelector) {
        return _hydrateParams(_proposalParams[proposalId]);
    }

    /**
     * @notice module:proposal-params
     */
    function _defaultProposalParams() internal pure virtual returns (bytes memory) {
        return abi.encode(address(0x0), bytes4(keccak256("simpleWeight(uint256)")));
    }

    /**
     * @notice module:proposal-params
     */
    function _hydrateParams(bytes memory params) internal pure returns (address token, bytes4 weightingSelector) {
        (token, weightingSelector) = abi.decode(params, (address, bytes4));
    }
}
