// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.17;

import "@std/Test.sol";
import "src/OrigamiGovernor.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiTimelock.sol";
import "src/governor/SimpleCounting.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/governance/IGovernor.sol";

abstract contract GovAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public proposer = address(0x3);
    address public voter = address(0x4);
    address public voter2 = address(0x5);
    address public voter3 = address(0x6);
    address public voter4 = address(0x7);
    address public newVoter = address(0x8);
    address public nonMember = address(0x9);
    address public anon = address(0xa);
}

// solhint-disable-next-line max-states-count
abstract contract GovHelper is GovAddressHelper, Test {
    OrigamiMembershipToken public memTokenImpl;
    TransparentUpgradeableProxy public memTokenProxy;
    OrigamiMembershipToken public memToken;
    ProxyAdmin public memTokenAdmin;

    OrigamiGovernanceToken public govTokenImpl;
    TransparentUpgradeableProxy public govTokenProxy;
    OrigamiGovernanceToken public govToken;
    ProxyAdmin public govTokenAdmin;

    OrigamiTimelock public timelockImpl;
    TransparentUpgradeableProxy public timelockProxy;
    OrigamiTimelock public timelock;
    ProxyAdmin public timelockAdmin;

    OrigamiGovernor public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernor public governor;
    ProxyAdmin public admin;

    constructor() {
        vm.startPrank(deployer);

        // deploy membership token via proxy
        memTokenAdmin = new ProxyAdmin();
        memTokenImpl = new OrigamiMembershipToken();
        memTokenProxy = new TransparentUpgradeableProxy(
            address(memTokenImpl),
            address(memTokenAdmin),
            ""
        );
        memToken = OrigamiMembershipToken(address(memTokenProxy));
        memToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", "https://example.com/metadata/");

        // deploy timelock via proxy
        timelockAdmin = new ProxyAdmin();
        timelockImpl = new OrigamiTimelock();
        timelockProxy = new TransparentUpgradeableProxy(
            address(timelockImpl),
            address(timelockAdmin),
            ""
        );
        timelock = OrigamiTimelock(payable(timelockProxy));
        timelock.initialize(0, new address[](0), new address[](0));

        // deploy gov token via proxy
        govTokenAdmin = new ProxyAdmin();
        govTokenImpl = new OrigamiGovernanceToken();
        govTokenProxy = new TransparentUpgradeableProxy(
            address(govTokenImpl),
            address(govTokenAdmin),
            ""
        );
        govToken = OrigamiGovernanceToken(address(govTokenProxy));
        govToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", 10000000000000000000000000000);

        // deploy governor via proxy
        admin = new ProxyAdmin();
        impl = new OrigamiGovernor();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        governor = OrigamiGovernor(payable(proxy));
        vm.stopPrank();
        governor.initialize("TestDAOGovernor", timelock, memToken, 91984, 91984, 10, 0);
        vm.startPrank(owner);

        // issue the voter some tokens
        memToken.safeMint(voter);
        memToken.safeMint(voter2);
        memToken.safeMint(voter3);
        memToken.safeMint(voter4);
        memToken.safeMint(newVoter);
        govToken.mint(voter, 100000000); // 10000^2
        govToken.mint(voter2, 225000000); // 15000^2
        govToken.mint(voter3, 56250000); // 7500^2
        govToken.mint(voter4, 306250000); // 17500^2
        govToken.mint(nonMember, 56250000);

        // let's travel an arbitrary and small amount of time forward so
        // proposals snapshot after these mints.
        vm.roll(42);
        vm.stopPrank();

        // self-delegate the NFT
        vm.prank(voter);
        memToken.delegate(voter);
        vm.prank(newVoter);
        memToken.delegate(newVoter);
        vm.prank(voter2);
        memToken.delegate(voter2);
        vm.prank(voter3);
        memToken.delegate(voter3);
        vm.prank(voter4);
        memToken.delegate(voter4);

        // selectively self-delegate the gov token for voters past the first one
        vm.prank(voter2);
        govToken.delegate(voter2);
        vm.prank(voter3);
        govToken.delegate(voter3);
        vm.prank(voter4);
        govToken.delegate(voter4);
    }
}

contract OrigamiGovernorTest is GovHelper {
    function testInformationalFunctions() public {
        assertEq(address(governor.timelock()), address(timelock));
        assertEq(governor.name(), "TestDAOGovernor");
        assertEq(governor.votingDelay(), 91984);
        assertEq(governor.votingPeriod(), 91984);
        assertEq(governor.proposalThreshold(), 0);
        assertEq(governor.quorumNumerator(), 10);
    }
}

contract OrigamiGovernorProposalTest is GovHelper {
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);
    }

    function testCanSubmitProposal() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);

        vm.prank(proposer);
        vm.expectEmit(true, true, true, false, address(governor));
        emit ProposalCreated(
            27805474734109527106678436453108520455405719583396555275526236178632433511344,
            proposer,
            targets,
            values,
            signatures,
            calldatas,
            91985,
            183969,
            "New proposal"
            );
        governor.propose(targets, values, calldatas, "New proposal");
    }

    function testCannotSubmitProposalWithZeroTargets() public {
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: empty proposal");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroValues() public {
        targets = new address[](1);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: invalid proposal length");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroCalldatas() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: invalid proposal length");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitSameProposalTwice() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        governor.propose(targets, values, calldatas, "New proposal");
        vm.expectRevert("Governor: proposal already exists");
        governor.propose(targets, values, calldatas, "New proposal");
    }

    function testProposalWithParamsTokenMustSupportIVotes() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.expectRevert("Governor: proposal token must support IVotes");
        governor.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(timelock), bytes4(keccak256("_simpleWeight(uint256)")))
        );
    }
}

contract OrigamiGovernorProposalVoteTest is GovHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("_simpleWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithDefaultParams() public {
        proposalId = governor.propose(targets, values, calldatas, "Simple Voting Proposal");
        vm.roll(92027);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        // our voting weight is 1 here, since this vote uses the membership token
        emit VoteCast(voter, proposalId, 0, 1, "");
        governor.castVote(proposalId, 0);
    }

    function testCanVoteOnProposalWithParams() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(92027);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 0, 100000000, "I like it", params);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I like it", params);
    }

    function testAddressWithoutMembershipTokenCanDelegateToMember() public {
        // self-delegate to get voting power
        vm.prank(nonMember);
        govToken.delegate(newVoter);

        vm.roll(92027);
        vm.prank(newVoter);

        // newVoter has the weight of nonMember's delegated tokens
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(newVoter, proposalId, 0, 56250000, "I vote with their weight!", params);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I vote with their weight!", params);
    }

    function testCanLimitVotingByWeight() public {
        // self-delegate to get voting power
        vm.prank(newVoter);
        govToken.delegate(newVoter);

        vm.roll(92027);
        vm.prank(newVoter);

        // newVoter has correctly self-delegated, but their weight is zero
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        governor.castVoteWithReasonAndParams(proposalId, 1, "I don't like it.", params);
    }

    function testCanLimitVotingToMembershipTokenHolders() public {
        vm.roll(92027);
        vm.prank(anon);

        vm.expectRevert("OrigamiGovernor: only members may vote");
        governor.castVoteWithReason(proposalId, 1, "I don't like it.");
    }
}

contract OrigamiGovernorProposalQuadraticVoteTest is GovHelper {
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("_quadraticWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithQuadraticCounting() public {
        // self-delegate to get voting power
        vm.startPrank(voter);
        govToken.delegate(voter);

        vm.roll(92027);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 0, 100000000, "I like it!", params);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I like it!", params);
    }
}

contract OrigamiGovernorProposalQuadraticVoteResultsTest is GovHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("_quadraticWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "Quadratic Proposal", params);
    }

    function testQuadraticVotingResultsAreCorrect() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // set block to first eligible voting block
        vm.roll(92027);

        // voter and voter2 collectively have fewer tokens than voter3 by
        // themselves, but quadratic weighting has the effect of making them
        // more powerful together than voter3 alone

        vm.prank(voter);
        governor.castVoteWithReasonAndParams(proposalId, uint8(SimpleCounting.VoteType.For), "I like it!", params);

        vm.prank(voter2);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.Against), "This is rubbish!", params
        );

        vm.prank(voter3);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.For), "I like it too! It's not rubbish at all!", params
        );

        vm.prank(voter4);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.Abstain), "I have no opinion.", params
        );

        vm.roll(92027 + 91984);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 15000);
        assertEq(forVotes, 17500);
        assertEq(abstainVotes, 17500);
    }
}
