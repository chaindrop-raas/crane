// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/AccessControl.sol";
import "src/governor/lib/GovernorCommon.sol";
import "src/governor/lib/GovernorQuorum.sol";
import "src/governor/lib/TokenWeightStrategy.sol";
import "src/interfaces/IGovernor.sol";
import "src/interfaces/IVotes.sol";
import "src/interfaces/utils/IEIP712.sol";
import "src/utils/GovernorStorage.sol";

import "@diamond/interfaces/IERC165.sol";
import "@oz/utils/cryptography/ECDSA.sol";

/**
 * @dev a really simple interface for a token that has a balanceOf function.
 */
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
    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant IDEMPOTENT_BALLOT_TYPEHASH =
        keccak256("IdempotentBallot(uint256 proposalId,uint8 support,string reason,uint256 nonce)");
    bytes32 public constant IDEMPOTENT_PROPOSAL_TYPEHASH = keccak256(
        "IdempotentProposal(address[] targets,uint256[] values,bytes[] calldatas,string description,uint256 nonce)"
    );

    /**
     * @notice Name of the governor instance (used in building the ERC712 domain separator).
     */
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

    /**
     * @notice the EIP712 domain separator for this contract.
     */
    function domainSeparatorV4() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(version())), block.chainid, address(this)
            )
        );
    }

    /**
     * @notice hashes proposal params to create a proposalId.
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the hash of the description of the proposal.
     * @return the proposalId.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice returns the current ProposalState for a proposal.
     * @param proposalId the id of the proposal.
     * @return the ProposalState.
     */
    function state(uint256 proposalId) public view returns (IGovernor.ProposalState) {
        IGovernor.ProposalState status = GovernorCommon.state(proposalId);
        return GovernorCommon.succededState(proposalId, status);
    }

    /**
     * @notice returns the snapshot timestamp for a proposal.
     * @param proposalId the id of the proposal.
     * @return the snapshot timestamp.
     */
    function proposalSnapshot(uint256 proposalId) public view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].snapshot;
    }

    /**
     * @notice returns the deadline timestamp for a proposal.
     * @param proposalId the id of the proposal.
     * @return the deadline block.
     */
    function proposalDeadline(uint256 proposalId) public view returns (uint256) {
        return GovernorStorage.proposalStorage().proposals[proposalId].deadline;
    }

    /**
     * @dev this is a shim for configuring the default counting strategy with a
     * concrete selector. We can't use the lib directly or else its functions
     * won't all be internal and would cause a separate contract deploy, as
     * opposed to inlining the code.
     */
    function simpleWeight(uint256 weight) public pure returns (uint256) {
        return TokenWeightStrategy.simpleWeight(weight);
    }

    /**
     * @dev Get votes for the given account at the given timestamp using proposal token.
     * @param account the account to get the vote weight for.
     * @param timestamp the block timestamp the snapshot is needed for.
     * @param proposalToken the token to use for counting votes.
     */
    function getVotes(address account, uint256 timestamp, address proposalToken) public view returns (uint256) {
        uint256 pastVotes = IVotes(proposalToken).getPastVotes(account, timestamp);
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
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on the proposal.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made on the proposal.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made on the proposal.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The strategy to use for counting votes.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategyBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256 proposalId) {
        address proposer = recoverProposer(targets, values, calldatas, description, nonce, v, r, s);

        require(GovernorStorage.getAccountNonce(proposer) == nonce, "OrigamiGovernor: invalid nonce");

        proposalId = createProposal(proposer, targets, values, calldatas, description, proposalToken, countingStrategy);

        GovernorStorage.incrementAccountNonce(proposer);
    }

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The strategy to use for counting votes.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategy(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) public returns (uint256) {
        return createProposal(msg.sender, targets, values, calldatas, description, proposalToken, countingStrategy);
    }

    /**
     * @notice Propose a new action to be performed by the governor, with params specifying proposal token and counting strategy. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param params The parameters of the proposal, encoded as a tuple of (proposalToken, countingStrategy).
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParamsBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256) {
        (address proposalToken, bytes4 countingStrategy) = decodeParams(params);
        return proposeWithTokenAndCountingStrategyBySig(
            targets, values, calldatas, description, proposalToken, countingStrategy, nonce, v, r, s
        );
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
    ) public returns (uint256) {
        (address proposalToken, bytes4 countingStrategy) = decodeParams(params);
        return proposeWithTokenAndCountingStrategy(
            targets, values, calldatas, description, proposalToken, countingStrategy
        );
    }

    /**
     * @notice Propose a new action to be performed by the governor. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        return proposeWithTokenAndCountingStrategyBySig(
            targets,
            values,
            calldatas,
            description,
            GovernorStorage.configStorage().defaultProposalToken,
            GovernorStorage.configStorage().defaultCountingStrategy,
            nonce,
            v,
            r,
            s
        );
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
        return proposeWithTokenAndCountingStrategy(
            targets,
            values,
            calldatas,
            description,
            GovernorStorage.configStorage().defaultProposalToken,
            GovernorStorage.configStorage().defaultCountingStrategy
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

    // TODO: this return type is specific to SimpleCounting, which probably
    // means it's not generic enough to be in the public interface
    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     */
    function proposalVotes(uint256 proposalId) public view virtual returns (uint256, uint256, uint256) {
        return SimpleCounting.simpleProposalVotes(proposalId);
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
        address voter = ECDSA.recover(
            ECDSA.toTypedDataHash(
                domainSeparatorV4(),
                keccak256(abi.encode(IDEMPOTENT_BALLOT_TYPEHASH, proposalId, support, keccak256(bytes(reason)), nonce))
            ),
            v,
            r,
            s
        );

        require(GovernorStorage.getAccountNonce(voter) == nonce, "OrigamiGovernor: invalid nonce");

        weight = _castVote(proposalId, voter, support, reason);

        GovernorStorage.incrementAccountNonce(voter);
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
     * @dev internal function to create a proposal.
     */
    function createProposal(
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) internal onlyThresholdTokenHolder(proposer) returns (uint256 proposalId) {
        require(
            IERC165(proposalToken).supportsInterface(type(IVotes).interfaceId),
            "Governor: proposal token must support IVotes"
        );
        require(GovernorStorage.isConfiguredToken(proposalToken), "Governor: proposal token not allowed");

        require(targets.length == values.length, "Governor: invalid proposal length");
        require(targets.length == calldatas.length, "Governor: invalid proposal length");
        require(targets.length > 0, "Governor: empty proposal");

        proposalId = GovernorCommon.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        GovernorStorage.ProposalCore storage ps =
            GovernorStorage.createProposal(proposalId, proposalToken, countingStrategy);

        emit ProposalCreated(
            proposalId,
            proposer,
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
     * @dev internal function to cast a vote on a proposal; restricts voting to members
     * TODO: the cast vote functions really should be part of the counting strategy, since they couple to the support type
     */
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason)
        internal
        onlyMember(account)
        returns (uint256 weight)
    {
        GovernorStorage.ProposalCore storage ps = GovernorStorage.proposal(proposalId);
        require(state(proposalId) == IGovernor.ProposalState.Active, "Governor: proposal not active");

        weight = getVotes(account, ps.snapshot, ps.proposalToken);
        require(weight > 0, "Governor: only accounts with delegated voting power can vote");

        SimpleCounting.setVote(proposalId, account, support, weight);

        emit VoteCast(account, proposalId, support, weight, reason);
    }

    /**
     * @dev recover the proposer address from signed proposal data
     */
    function recoverProposer(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32[] memory encodedCallData = new bytes32[](calldatas.length);
        for (uint256 i = 0; i < calldatas.length; i++) {
            encodedCallData[i] = keccak256(calldatas[i]);
        }
        bytes32 structHash = keccak256(
            abi.encode(
                IDEMPOTENT_PROPOSAL_TYPEHASH,
                keccak256(abi.encodePacked(targets)),
                keccak256(abi.encodePacked(values)),
                keccak256(abi.encodePacked(encodedCallData)),
                keccak256(bytes(description)),
                nonce
            )
        );
        return ECDSA.recover(ECDSA.toTypedDataHash(domainSeparatorV4(), structHash), v, r, s);
    }

    /**
     * @dev decode the bytes param format into the proposal token and counting strategy.
     */
    function decodeParams(bytes memory params) internal view returns (address proposalToken, bytes4 countingStrategy) {
        if (keccak256(params) == keccak256("")) {
            proposalToken = GovernorStorage.configStorage().defaultProposalToken;
            countingStrategy = GovernorStorage.configStorage().defaultCountingStrategy;
        } else {
            (proposalToken, countingStrategy) = abi.decode(params, (address, bytes4));
        }
    }

    /**
     * @dev restricts calling functions with this modifier to holders of the membership token.
     */
    modifier onlyMember(address account) {
        require(
            BalanceToken(GovernorStorage.configStorage().membershipToken).balanceOf(account) > 0,
            "OrigamiGovernor: only members may vote"
        );
        _;
    }

    /**
     * @dev restricts calling functions with this modifier to those who hold at least the threshold amount of the threshold token.
     */
    modifier onlyThresholdTokenHolder(address account) {
        GovernorStorage.GovernorConfig storage cs = GovernorStorage.configStorage();
        require(
            getVotes(account, block.timestamp, cs.proposalThresholdToken) >= cs.proposalThreshold,
            "Governor: proposer votes below proposal threshold"
        );
        _;
    }
}
