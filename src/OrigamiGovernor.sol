// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/OrigamiMembershipToken.sol";
import "src/governor/GovernorWithProposalParams.sol";
import "src/governor/SimpleCounting.sol";
import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @title Origami Governor
/// @author Stephen Caudill
/// @notice This contract enables DAO governance and decision making and is supported by and depended upon by the Origami platform and ecosystem.
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
    /// @notice the role hash for granting the ability to cancel a timelocked proposal. This role is not granted as part of deployment. It should be granted only in the event of an emergency.
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    /// @notice default token is initialized to the DAOs membership token and is used when no token is specified via proposal params
    IVotesUpgradeable public defaultToken;

    /// @notice the constructor is not used since the contract is upgradeable except to disable initializers in the implementations that are deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev this function is used to initialize the contract. It is called during contract deployment.
     * @notice this function is not intended to be called by external users.
     * @param delay Delay between proposal creation and voting start
     * @param period Period during which voting is open
     * @param quorumPercentage_ Percentage of circulating supply of the token required to vote for a proposal to be approved
     * @param threshold quantity of the default token the proposer must hold to create a proposal. This should always be set to 1, since it uses a Singleton Membership NFT.
     * @param admin the address that will be granted the admin role and will be able to grant the canceller role.
     */
    function initialize(
        string calldata governorName,
        TimelockControllerUpgradeable timelock,
        IVotesUpgradeable token_,
        uint24 delay,
        uint24 period,
        uint8 quorumPercentage_,
        uint16 threshold,
        address admin
    ) public initializer {
        __Governor_init(governorName);
        __GovernorSettings_init(delay, period, threshold);
        __GovernorVotesQuorumFraction_init(quorumPercentage_);
        __GovernorTimelockControl_init(timelock);
        defaultToken = token_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice The domain separator is available for use in the EIP712 signature of the vote casting by sig functions.
     * @dev Returns the contract's {EIP712} domain separator.
     * @return bytes32 representing the domain separator.
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice The base proposal creation function. Since we extend GovernorWithProposalParams, this function calls into it and uses _defaultProposalParams.
     * @return proposalId the id of the newly created proposal.
     * module:core
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
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     * module:core
     */
    function votingDelay() public view override (IGovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     * module:core
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
     * @notice the vote weight needed based on the token holdings snapshot at time of proposal creation.
     * @dev Returns the quorum for the proposal: `supply * numerator / denominator`. This used to take blockNumber as a parameter, but now it takes proposalId, both uint256. Need to make sure this doesn't have any unintended consequences.
     * module:core
     */
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
     * @notice the state (Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed) the proposal is in.
     * @return the ProposalState of the proposal.
     * module:core
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
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     * module:core
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
     * @notice public interface to determine which interfaces this contract supports.
     * @return boolean - true if the interface is supported.
     * module:core
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
     * @notice Version of the governor instance (used in building the ERC712 domain separator).
     * @dev Indicate v1.1.0 so it's understood we have diverged from the OZ implementation.
     * @return The semantic version.
     * module:core
     */
    function version() public pure override (GovernorUpgradeable, IGovernorUpgradeable) returns (string memory) {
        return "1.1.0";
    }

    /**
     * @notice public function to cancel a proposal
     * module:core
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public onlyRole(CANCELLER_ROLE) {
        _cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev overridden from GovernorVotesUpgradeable to restrict voting to holders of the default token.
     * module:voting
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
     * @dev specify the implementation for the overrides.
     * module:core
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
     * @dev specify the implementation for the overrides.
     * module:core
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
     * @dev an override that is compatible with the GovernorWithProposalParams interface.
     * module:reputation
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
     * @dev this delegates weight calculation to the strategy specified in the params
     * module:core
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = _getProposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support,, uint256 calculatedWeight) = _getVote(proposalId, voter);
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
     * @dev implementation of {Governor-_quorumReached} that is compatible with the GovernorWithProposalParams interface.
     * module:core
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);
        (, bytes4 weightingSelector) = _getProposalParams(proposalId);
        return applyWeightStrategy(quorum(proposalId), weightingSelector) <= forVotes + abstainVotes;
    }

    /**
     * @dev implementation of {Governor-_voteSucceeded} that is compatible with the GovernorWithProposalParams interface.
     * module:core
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
        return forVotes > againstVotes;
    }

    /**
     * @dev specify the implementation for the overrides.
     * module:core
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
     * @notice restricts calling functions with this modifier to holders of the default token.
     * module:voting
     */
    modifier onlyMember(address account) {
        require(
            OrigamiMembershipToken(address(defaultToken)).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }
}
