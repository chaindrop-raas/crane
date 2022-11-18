// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@oz-upgradeable/governance/GovernorUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz/governance/utils/IVotes.sol";
import "@oz/utils/introspection/ERC165.sol";

abstract contract GovernorWithProposalParams is
    Initializable,
    GovernorUpgradeable
{
    mapping(uint256 => bytes) private _proposalParams;

    function hydrateParams(bytes memory params)
        public
        pure
        returns (address token, bytes4 counterSignature)
    {
        (token, counterSignature) = abi.decode(params, (address, bytes4));
    }

    function _defaultProposalParams() internal virtual pure returns (bytes memory) {
        return abi.encode(address(0x0), bytes4(keccak256("_simpleWeight(uint256)")));
    }

    function getProposalParams(uint256 proposalId)
        public
        view
        returns (address token, bytes4 counterSignature)
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
        if(keccak256(params) == keccak256(_defaultProposalParams())) {
            return super.propose(targets, values, calldatas, description);
        }
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
