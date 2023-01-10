// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/OrigamiTimelock.sol";
import "src/governor/lib/GovernorCommon.sol";
import "src/governor/lib/GovernorQuorum.sol";
import "src/governor/lib/ProposalParams.sol";
import "src/interfaces/IGovernor.sol";
import "src/interfaces/utils/IEIP712.sol";
import "src/utils/AccessControl.sol";
import "src/utils/GovernorStorage.sol";

import "@diamond/interfaces/IERC165.sol";
import "@oz/utils/cryptography/ECDSA.sol";
import "@oz/governance/utils/IVotes.sol";
import "@oz/utils/Address.sol";

interface BalanceToken {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title Origami Governor Core Facet
 * @author Origami
 * @notice Core facet of the Origami Governor. All logic that is not specific to Counting or Voting strategies is here.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorCoreFacet is AccessControl, IEIP712, IGovernor {
    /// @notice the role hash for granting the ability to cancel a timelocked proposal. This role is not granted as part of deployment. It should be granted only in the event of an emergency.
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH =
        keccak256("ExtendedIdempotentBallot(uint256 proposalId,uint8 support,string reason,uint256 nonce,bytes params)");
    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function name() public view returns (string memory) {
        return GovernorStorage.configStorage().name;
    }

    /**
     * @notice Version of the governor instance (used in building the ERC712 domain separator).
     * @dev Indicate v1.1.0 so it's understood we have diverged from strict Governor Bravo compliance.
     * @return The semantic version.
     */
    function version() public pure returns (string memory) {
        return "1.1.0";
    }

    function domainSeparatorV4() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(version())), block.chainid, address(this)
            )
        );
    }

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
    }

    function state(uint256 proposalId) public view returns (IGovernor.ProposalState) {
        IGovernor.ProposalState status = GovernorCommon.state(proposalId);
        return GovernorCommon.succededState(proposalId, status);
    }

    function proposalSnapshot(uint256 proposalId) public view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].snapshot;
    }

    function proposalDeadline(uint256 proposalId) public view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].deadline;
    }

    /**
     * @dev Get votes for the given account at the given block number using proposal params.
     * @param account the account to get the vote weight for.
     * @param blockNumber the block number the snapshot was taken at.
     * @param params the params of the proposal.
     */
    function getVotes(address account, uint256 blockNumber, bytes storage params) internal view returns (uint256) {
        address tokenForProposal;
        if (keccak256(params) == keccak256("")) {
            tokenForProposal = GovernorStorage.configStorage().membershipToken;
        } else {
            (tokenForProposal,) = GovernorProposalParams.decodeProposalParams(params);
        }
        return getVotes(account, blockNumber, tokenForProposal);
    }

    /**
     * @dev Get votes for the given account at the given block number using proposal token.
     * @param account the account to get the vote weight for.
     * @param blockNumber the block number the snapshot was taken at.
     * @param proposalToken the token to use for counting votes.
     */
    function getVotes(address account, uint256 blockNumber, address proposalToken) public view returns (uint256) {
        uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, blockNumber);
        return pastVotes;
    }

    /**
     * @notice Indicates whether or not an account has voted on a proposal.
     * @dev See {IGovernor-_hasVoted}. Note that we differ from the base implementation in that we don't want to prevent multiple votes, we instead update their previous vote.
     * @return true if the account has voted on the proposal, false otherwise.
     */
    function hasVoted(uint256 proposalId, address account) public view returns (bool) {
        return GovernorStorage.proposalHasVoted(proposalId, account);
    }

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy.
     * @dev See {GovernorUpgradeable-_propose}.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param params the encoded bytes that specify the proposal's counting strategy and the token to use for counting.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) public returns (uint256 proposalId) {
        address proposalThresholdToken = GovernorStorage.configStorage().proposalThresholdToken;
        uint256 proposerVotes = getVotes(msg.sender, block.number - 1, proposalThresholdToken);
        require(
            proposerVotes >= GovernorStorage.configStorage().proposalThreshold,
            "Governor: proposer votes below proposal threshold"
        );

        address proposalToken;
        if (keccak256(params) == keccak256("")) {
            proposalToken = GovernorStorage.configStorage().membershipToken;
        } else {
            (proposalToken,) = abi.decode(params, (address, bytes4));
        }
        require(
            IERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );

        require(targets.length == values.length, "Governor: invalid proposal length");
        require(targets.length == calldatas.length, "Governor: invalid proposal length");
        require(targets.length > 0, "Governor: empty proposal");

        proposalId = GovernorCommon.hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        // start populating the new ProposalCore struct
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        require(ps.snapshot == 0, "Governor: proposal already exists");

        ps.params = params;
        ps.quorumNumerator = GovernorStorage.configStorage().quorumNumerator;
        // TODO: circle back and factor away from block.number and to
        // block.timestamp so we can deploy to chains like Optimism.
        // --
        // An epoch exceeding max UINT64 is 584,942,417,355 years from now. I
        // feel pretty safe casting this.
        ps.snapshot = uint64(block.number) + GovernorStorage.configStorage().votingDelay;
        ps.deadline = ps.snapshot + GovernorStorage.configStorage().votingPeriod;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            ps.snapshot,
            ps.deadline,
            description
            );
    }

    /**
     * @notice Get the configured quorum for a proposal.
     * @param proposalId The id of the proposal to get the quorum for.
     * @return The quorum for the given proposal.
     */
    function quorum(uint256 proposalId) public view returns (uint256) {
        return GovernorQuorum.quorum(proposalId);
    }

    /**
     * @notice propose a new action to be performed by the governor.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @return proposalId The id of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId) {
        return proposeWithParams(targets, values, calldatas, description, "");
    }

    // TODO: the cast vote functions really should be part of the counting strategy, since they couple to the support type

    // @dev internal function to cast a vote on a proposal; restricts voting to members
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason)
        internal
        onlyMember(account)
        returns (uint256 weight)
    {
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        require(state(proposalId) == IGovernor.ProposalState.Active, "Governor: proposal not active");

        weight = getVotes(account, ps.snapshot, ps.params);
        require(weight > 0, "Governor: only accounts with delegated voting power can vote");

        SimpleCounting.setVote(proposalId, account, support, weight, ps.params);

        emit VoteCast(account, proposalId, support, weight, reason);
    }

    /**
     * @notice Cast a vote on a proposal.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @return weight The weight of the vote.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256) {
        return _castVote(proposalId, msg.sender, support, "");
    }

    /**
     * @notice Cast a vote on a proposal with a reason.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @return weight The weight of the vote.
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256) {
        return _castVote(proposalId, msg.sender, support, reason);
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
     * @notice Cast a vote on a proposal with a reason by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256 weight) {
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        address voter = ECDSA.recover(
            ECDSA.toTypedDataHash(
                domainSeparatorV4(),
                keccak256(
                    abi.encode(
                        EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH,
                        proposalId,
                        support,
                        keccak256(bytes(reason)),
                        nonce,
                        keccak256(ps.params)
                    )
                )
            ),
            v,
            r,
            s
        );

        require(nonces(voter) == nonce, "OrigamiGovernor: invalid nonce");

        weight = _castVote(proposalId, voter, support, reason);

        // since voter nonce is capped by the total number of proposals ever, it
        // is extraordinarily unlikely that we can overflow it.
        unchecked {
            GovernorStorage.proposalStorage().nonces[voter]++;
        }
    }

    /**
     * @notice Cast a vote on a proposal by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight)
    {
        return castVoteWithReasonBySig(proposalId, support, "", nonce, v, r, s);
    }

    /**
     * @notice restricts calling functions with this modifier to holders of the default token.
     * module:voting
     */
    modifier onlyMember(address account) {
        require(
            BalanceToken(GovernorStorage.configStorage().membershipToken).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }
}
