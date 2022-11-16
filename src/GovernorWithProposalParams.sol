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
    mapping(uint256 => ProposalParams) private _proposalParams;

    struct ProposalParams {
        address token;
    }

    function hydrateParams(bytes memory params) public pure returns (address) {
        return abi.decode(params, (address));
    }

    function _defaultProposalParams() internal virtual returns (bytes memory) {
        address defaultToken = address(token);
        return abi.encode(defaultToken);
    }

    function getProposalParams(uint256 proposalId)
        public
        view
        returns (address token)
    {
        ProposalParams memory params = _proposalParams[proposalId];
        return params.token;
    }

    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) public virtual returns (uint256) {
        address proposalToken = hydrateParams(params);
        require(
            ERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );

        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        ProposalParams memory proposalParams;
        proposalParams.token = proposalToken;
        _proposalParams[proposalId] = proposalParams;

        return proposalId;
    }
}
