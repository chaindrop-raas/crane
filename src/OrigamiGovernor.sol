// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "src/GovernorWithProposalParams.sol";
import "src/OrigamiMembershipToken.sol";
import "src/governor/SimpleCounting.sol";
import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiGovernor is
    Initializable,
    AccessControlUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorWithProposalParams,
    SimpleCounting
{
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    IVotesUpgradeable public defaultToken;

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
        uint16 _proposalThreshold,
        address _admin
    ) public initializer {
        __Governor_init(governorName);
        __GovernorSettings_init(_votingDelay, _votingPeriod, _proposalThreshold);
        __GovernorVotesQuorumFraction_init(quorumPercentage);
        __GovernorTimelockControl_init(_timelock);
        defaultToken = _defaultToken;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CANCELLER_ROLE, _admin);
    }

    /**
     * @dev Returns the contract's {EIP712} domain separator.
     */
    // solhint-disable-next-line func-name-mixedcase
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice module:core
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override (GovernorUpgradeable, IGovernorUpgradeable) returns (uint256) {
        return proposeWithParams(targets, values, calldatas, description, _defaultProposalParams());
    }

    /**
     * @notice module:core
     */
    function votingDelay() public view override (IGovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice module:core
     */
    function votingPeriod()
        public
        view
        override (IGovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    /**
     * @dev Returns the quorum for a block number, in terms of number of votes: `supply * numerator / denominator`.
     * @notice module:core
     */
    // NB: this used to take blockNumber as a parameter, but now it takes
    // proposalId, both uint256. Need to make sure this doesn't have any
    // unintended consequences.
    function quorum(uint256 proposalId)
        public
        view
        override (GovernorVotesQuorumFractionUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        (address proposalToken,) = _getProposalParams(proposalId);
        uint256 snapshot = proposalSnapshot(proposalId);
        uint256 snapshotTotalSupply = VotesUpgradeable(proposalToken).getPastTotalSupply(snapshot);
        return (snapshotTotalSupply * quorumNumerator(snapshot)) / quorumDenominator();
    }

    /**
     * @notice module:core
     */
    function state(uint256 proposalId)
        public
        view
        override (GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /**
     * @notice module:core
     */
    function proposalThreshold()
        public
        view
        override (GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /**
     * @notice module:core
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (GovernorUpgradeable, GovernorTimelockControlUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice module:core
     * @dev Version of the governor instance (used in building the ERC712 domain
     *      separator). Indicate v1.1.0 so it's understood we have diverged from
     *      the OZ implementation.
     * @return The version number.
     */
    function version() public pure override(GovernorUpgradeable, IGovernorUpgradeable) returns (string memory) {
        return "1.1.0";
    }

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public onlyRole(CANCELLER_ROLE) {
        _cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice module:voting
     */

    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        override
        onlyMember(account)
        returns (uint256)
    {
        return super._castVote(proposalId, account, support, reason, params);
    }

    /**
     * @notice module:core
     */
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override (GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice module:core
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override (GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice module:reputation
     */

    function _getVotes(address account, uint256 blockNumber, bytes memory params)
        internal
        view
        override (GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (uint256)
    {
        if (keccak256(params) == keccak256(_defaultParams())) {
            return defaultToken.getPastVotes(account, blockNumber);
        } else {
            (address proposalToken,) = _hydrateParams(params);
            uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, blockNumber);
            require(pastVotes > 0, "Governor: only accounts with delegated voting power can vote");
            return pastVotes;
        }
    }

    /**
     * @notice module:core
     * @dev this delegates weight calculation to the strategy specified in the params
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        (, bytes4 weightingSelector) = _getProposalParams(proposalId);
        address[] memory voters = _getProposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support, uint256 weight) = _getVote(proposalId, voter);
            uint256 calculatedWeight = applyWeightStrategy(weight, weightingSelector);
            if (support == VoteType.Abstain) {
                abstainVotes += calculatedWeight;
            } else if (support == VoteType.For) {
                forVotes += calculatedWeight;
            } else if (support == VoteType.Against) {
                againstVotes += calculatedWeight;
            }
        }
    }

    /**
     * @notice module:core
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);
        (, bytes4 weightingSelector) = _getProposalParams(proposalId);
        return applyWeightStrategy(quorum(proposalId), weightingSelector) <= forVotes + abstainVotes;
    }

    /**
     * @notice module:core
     * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);

        return forVotes > againstVotes;
    }

    /**
     * @notice module:core
     */
    function _executor()
        internal
        view
        override (GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    /**
     * @notice module:voting
     */
    modifier onlyMember(address account) {
        require(
            OrigamiMembershipToken(address(defaultToken)).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }
}
