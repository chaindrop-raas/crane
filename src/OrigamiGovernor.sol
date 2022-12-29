// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/OrigamiMembershipToken.sol";
import "src/governor/GovernorWithProposalParams.sol";
import "src/governor/SimpleCounting.sol";
import "src/governor/GovernorStorage.sol";
import "src/governor/GovernorQuorumFacet.sol";
import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/governance/GovernorUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@oz-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz-upgradeable/utils/CountersUpgradeable.sol";

/// @title Origami Governor
/// @author Stephen Caudill
/// @notice This contract enables DAO governance and decision making and is supported by and depended upon by the Origami platform and ecosystem.
/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiGovernor is
    Initializable,
    AccessControlUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorWithProposalParams,
    GovernorQuorumFacet,
    SimpleCounting
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @notice the role hash for granting the ability to cancel a timelocked proposal. This role is not granted as part of deployment. It should be granted only in the event of an emergency.
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    bytes32 public constant EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH =
        keccak256("ExtendedIdempotentBallot(uint256 proposalId,uint8 support,string reason,uint256 nonce,bytes params)");

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
        TimelockControllerUpgradeable timelock_,
        IVotesUpgradeable token_,
        uint24 delay,
        uint24 period,
        uint8 quorumPercentage_,
        uint16 threshold,
        address admin
    ) public initializer {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();

        config.name = governorName;
        config.admin = admin;
        config.timelock = address(timelock_);
        config.membershipToken = address(token_);
        config.votingDelay = delay;
        config.votingPeriod = period;
        config.quorumNumerator = quorumPercentage_;
        config.proposalThreshold = threshold;
        config.proposalThresholdToken = address(token_);

        __Governor_init(governorName);
        __GovernorSettings_init(delay, period, threshold);
        __GovernorTimelockControl_init(timelock_);
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
     * @notice retrieve the current voting nonce for a given voter.
     * @param owner the address of the nonce owner.
     * @return the next nonce for the owner.
     */
    function nonces(address owner) public view returns (uint256) {
        GovernorStorage.ProposalStorage storage ps = GovernorStorage.proposalStorage();
        return ps.nonces[owner];
    }

    /**
     * @notice Indicates whether or not an account has voted on a proposal.
     * @dev See {IGovernor-_hasVoted}. Note that we differ from the base implementation in that we don't want to prevent multiple votes, we instead update their previous vote.
     * @return true if the account has voted on the proposal, false otherwise.
     * module:voting
     */
    function hasVoted(uint256 proposalId, address account) public view override virtual returns (bool) {
        return GovernorStorage.proposalHasVoted(proposalId, account);
    }

    /// START SHIM FUNCTIONS FOR GovernorUpgradeable COMPATIBILITY

    function _countVote(uint256 proposalId, address account, uint8 support, uint256 weight, bytes memory params)
        internal
        override
    {
        setVote(proposalId, account, support, weight, params);
    }

    function COUNTING_MODE() public pure override(IGovernorUpgradeable, SimpleCounting) returns (string memory) {
        return SimpleCounting.COUNTING_MODE();
    }

    /// END SHIM FUNCTIONS FOR GovernorUpgradeable COMPATIBILITY

    /**
     * @notice The base proposal creation function.
     * @dev Since we extend GovernorWithProposalParams, this function calls into it and uses _defaultProposalParams.
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
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingDelay;
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
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.votingPeriod;
    }

    /**
     * @notice the state (Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed) the proposal is in.
     * @return the ProposalState of the proposal.
     * @param proposalId the proposalId of the proposal we are returning ProposalState for.
     * @ return the current state of the indicated proposal as a ProposalState.
     *  ^ natspec has an error with return specs for returns when the return uses a struct. This is a known issue. Adding a space to circumvent the error.
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
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        return config.proposalThreshold;
    }

    /**
     * @notice public interface to determine which interfaces this contract supports.
     * @param interfaceId the interface to check for support.
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
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the descriptionHash of the proposal.
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
     * @param proposalId the id of the proposal to cast a vote for.
     * @param account the account doing the voting
     * @param support the support of the vote (0 = against, 1 = for, 2 = abstain)
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
     * @notice voting by sig without nonce is not supported.
     */
    function castVoteBySig(uint256, uint8, uint8, bytes32, bytes32)
        public
        virtual
        override (GovernorUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        revert("OrigamiGovernor: not implemented");
    }

    /**
     * @notice voting by sig without nonce is not supported.
     */
    function castVoteWithReasonAndParamsBySig(uint256, uint8, string calldata, bytes memory, uint8, bytes32, bytes32)
        public
        virtual
        override (GovernorUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        revert("OrigamiGovernor: not implemented");
    }

    /**
     * @notice cast vote by signature. Requires a nonce and uses the ExtendedImmutableBallot typehash.
     * @dev the nonce is used to prevent replay attacks. It is incremented after each successful vote.
     * @param proposalId the id of the proposal to vote on.
     * @param support the support of the vote (0 = against, 1 = for, 2 = abstain)
     * @param nonce the nonce of the voter.
     * @param v the recovery byte of the signature.
     * @param r half of the ECDSA signature pair.
     * @param s half of the ECDSA signature pair.
     * @return weight - the weight of the vote.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        public
        returns (uint256)
    {
        bytes memory params = getProposalParamsBytes(proposalId);
        return castVoteWithReasonAndParamsBySig(proposalId, support, "", params, nonce, v, r, s);
    }

    /**
     * @notice cast vote with reason by signature. Requires a nonce and uses the ExtendedImmutableBallot typehash.
     * @dev the nonce is used to prevent replay attacks. It is incremented after each successful vote.
     * @param proposalId the id of the proposal to vote on.
     * @param support the support of the vote (0 = against, 1 = for, 2 = abstain)
     * @param reason the reason for the vote.
     * @param nonce the nonce of the voter.
     * @param v the recovery byte of the signature.
     * @param r half of the ECDSA signature pair.
     * @param s half of the ECDSA signature pair.
     * @return weight - the weight of the vote.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256) {
        bytes memory params = getProposalParamsBytes(proposalId);
        return castVoteWithReasonAndParamsBySig(proposalId, support, reason, params, nonce, v, r, s);
    }

    /**
     * @notice cast vote with reason and params by signature. Requires a nonce and uses the ExtendedImmutableBallot typehash.
     * @dev the nonce is used to prevent replay attacks. It is incremented after each successful vote.
     * @param proposalId the id of the proposal to vote on.
     * @param support the support of the vote (0 = against, 1 = for, 2 = abstain)
     * @param reason the reason for the vote.
     * @param params the params for the vote.
     * @param nonce the nonce of the voter.
     * @param v the recovery byte of the signature.
     * @param r half of the ECDSA signature pair.
     * @param s half of the ECDSA signature pair.
     * @return weight - the weight of the vote.
     */
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256 weight) {
        address voter = ECDSAUpgradeable.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH,
                        proposalId,
                        support,
                        keccak256(bytes(reason)),
                        nonce,
                        keccak256(params)
                    )
                )
            ),
            v,
            r,
            s
        );

        require(nonces(voter) == nonce, "OrigamiGovernor: invalid nonce");

        weight = _castVote(proposalId, voter, support, reason, params);

        // since voter nonce is capped by the total number of proposals ever, it
        // is extraordinarily unlikely that we can overflow it.
        unchecked {
            GovernorStorage.proposalStorage().nonces[voter]++;
        }
    }

    /**
     * @dev specify the implementation for the overrides.
     * @param proposalId the id of the proposal to execute.
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the descriptionHash of the proposal.
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
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the descriptionHash of the proposal.
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

    function membershipToken() public view returns (IVotes) {
        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        return IVotes(cs.membershipToken);
    }

    /**
     * @dev an override that is compatible with the GovernorWithProposalParams interface.
     * @param account the account to get the vote weight for.
     * @param blockNumber the block number the snapshot was taken at.
     * @param params the params of the proposal.
     * module:reputation
     */
    function _getVotes(address account, uint256 blockNumber, bytes memory params)
        internal
        view
        override (GovernorUpgradeable)
        returns (uint256)
    {
        if (keccak256(params) == keccak256("")) {
            return membershipToken().getPastVotes(account, blockNumber);
        } else {
            (address proposalToken,) = hydrateParams(params);
            uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, blockNumber);
            require(pastVotes > 0, "Governor: only accounts with delegated voting power can vote");
            return pastVotes;
        }
    }

    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     * module:core
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = getProposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support,, uint256 calculatedWeight) = getVote(proposalId, voter);
            if (support == VoteType.Abstain) {
                abstainVotes += calculatedWeight;
            } else if (support == VoteType.For) {
                forVotes += calculatedWeight;
            } else if (support == VoteType.Against) {
                againstVotes += calculatedWeight;
            }
        }
    }

    function quorum(uint256 proposalId)
        public
        view
        override (GovernorQuorumFacet, IGovernorUpgradeable)
        returns (uint256)
    {
        return super.quorum(proposalId);
    }

    /**
     * @dev implementation of {Governor-_quorumReached} that is compatible with the GovernorWithProposalParams interface.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the quorum has been reached.
     * module:counting
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);
        (, bytes4 weightingSelector) = getProposalParams(proposalId);
        return applyWeightStrategy(quorum(proposalId), weightingSelector) <= forVotes + abstainVotes;
    }

    /**
     * @dev implementation of {Governor-_voteSucceeded} that is compatible with the GovernorWithProposalParams interface.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the vote has succeeded.
     * module:core
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
        return forVotes > againstVotes;
    }

    /**
     * @dev specify the implementation for the overrides.
     * @return the address of the designator executor for proposals on this governor.
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
            OrigamiMembershipToken(address(membershipToken())).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }
}
