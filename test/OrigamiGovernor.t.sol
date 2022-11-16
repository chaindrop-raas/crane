// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.17;

import "@std/Test.sol";
import "src/OrigamiGovernor.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiTimelock.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/governance/IGovernor.sol";

abstract contract GovAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public proposer = address(0x3);
    address public voter = address(0x4);
}

// solhint-disable-next-line max-states-count
abstract contract GovHelper is GovAddressHelper, Test {
    OrigamiMembershipToken public memTokenImpl;
    TransparentUpgradeableProxy public memTokenProxy;
    OrigamiMembershipToken public memToken;
    ProxyAdmin public memTokenAdmin;

    OrigamiTimelock public timelockImpl;
    TransparentUpgradeableProxy public timelockProxy;
    OrigamiTimelock public timelock;
    ProxyAdmin public timelockAdmin;

    OrigamiGovernor public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernor public governor;
    ProxyAdmin public admin;

    OrigamiGovernanceToken public govTokenImpl;
    TransparentUpgradeableProxy public govTokenProxy;
    OrigamiGovernanceToken public govToken;
    ProxyAdmin public govTokenAdmin;

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
        memToken.initialize(
            owner,
            "Deciduous Tree DAO Membership",
            "DTDM",
            "https://example.com/metadata/"
        );

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
        govToken.initialize(
            owner,
            "Deciduous Tree DAO Membership",
            "DTDM",
            10000000000000000000000000000
        );

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
        governor.initialize(
            "TestDAOGovernor",
            timelock,
            memToken,
            91984,
            91984,
            10,
            0
        );
        vm.startPrank(owner);

        // issue the voter some tokens
        memToken.safeMint(voter);
        govToken.mint(voter, 100000000);

        vm.stopPrank();
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

    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    event VoteCastWithParams(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason,
        bytes params
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
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "New proposal"
        );
        vm.roll(91986);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCast(voter, proposalId, 0, 0, "");
        governor.castVote(proposalId, 0);
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

    function testCanRetrieveProposalParams() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        uint256 proposalId = governor.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(govToken))
        );
        assertEq(governor.getProposalParams(proposalId), address(govToken));
    }

    function testProposalWithParamsTokenMustSupportIVotes() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.expectRevert("Governor: proposal token does not support IVotes");
        governor.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(timelock))
        );
    }

    function testCanVoteOnProposalWithParams() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";
        bytes memory params = abi.encode(address(govToken));

        uint256 proposalId = governor.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            params
        );
        vm.roll(91986);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 0, 0, "I like it", params);
        governor.castVoteWithReasonAndParams(
            proposalId,
            0,
            "I like it",
            params
        );
    }
}
