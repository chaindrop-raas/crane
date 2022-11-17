// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@std/console.sol";
import "./GovernorWithProposalParams.sol";
import "./OrigamiMembershipToken.sol";
import "./OrigamiGovernor/counting/SimpleCounting.sol";
import "@oz-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiGovernor is
    Initializable,
    GovernorSettingsUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorWithProposalParams,
    SimpleCounting
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string calldata governorName,
        TimelockControllerUpgradeable _timelock,
        IVotesUpgradeable _defaultToken,
        uint24 _votingDelay,
        uint24 _votingPeriod,
        uint8 quorumPercentage,
        uint16 _proposalThreshold
    ) public initializer {
        __Governor_init(governorName);
        __GovernorSettings_init(
            _votingDelay,
            _votingPeriod,
            _proposalThreshold
        );
        __GovernorVotes_init(_defaultToken);
        __GovernorVotesQuorumFraction_init(quorumPercentage);
        __GovernorTimelockControl_init(_timelock);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override onlyMember(account) returns (uint256) {
        return super._castVote(proposalId, account, support, reason, params);
    }

    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory params
    ) internal view override(GovernorUpgradeable, GovernorVotesUpgradeable) returns (uint256) {
        if(keccak256(params) == keccak256(_defaultParams())) {
            return super._getVotes(account, blockNumber, params);
        } else {
            (address proposalToken,) = hydrateParams(params);
            uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, blockNumber);
            require(pastVotes > 0, "Governor: only accounts with delegated voting power can vote");
            return pastVotes;
        }
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal override(GovernorUpgradeable) {
        if(keccak256(params) == keccak256(_defaultParams())) {
            countVote(proposalId, account, support, weight, params);
        } else {
            (, address counter) = hydrateParams(params);
            ICounting(counter).countVote(proposalId, account, support, weight, params);
        }
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(GovernorUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        return
            proposeWithParams(
                targets,
                values,
                calldatas,
                description,
                _defaultProposalParams()
            );
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    modifier onlyMember(address account) {
        require(
            OrigamiMembershipToken(address(token)).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }
}
