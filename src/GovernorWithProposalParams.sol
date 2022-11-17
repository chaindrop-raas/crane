// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@oz-upgradeable/governance/GovernorUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz/governance/utils/IVotes.sol";
import "@oz/utils/introspection/ERC165.sol";

abstract contract GovernorWithProposalParams is
    Initializable,
    GovernorUpgradeable,
    GovernorVotesUpgradeable
{
    mapping(uint256 => bytes) private _proposalParams;

    function hydrateParams(bytes memory params)
        public
        pure
        returns (address token, address counter)
    {
        (token, counter) = abi.decode(params, (address, address));
    }

    function _defaultProposalParams() internal virtual returns (bytes memory) {
        // in the case of OrigamiGovernor, if we fall back to defaults we won't
        // use the counting implementation, so we have a nice steak instead.
        return abi.encode(address(token), address(0xbeef));
    }

    function getProposalParams(uint256 proposalId)
        public
        view
        returns (address token, address counter)
    {
        return hydrateParams(_proposalParams[proposalId]);
    }

    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) public virtual returns (uint256) {
        (address proposalToken,) = hydrateParams(params);
        require(
            ERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );

        uint256 proposalId =
            super.propose(targets, values, calldatas, description);

        _proposalParams[proposalId] = params;

        return proposalId;
    }
}
