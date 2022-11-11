// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.17;

import "@std/Test.sol";
import "src/OrigamiGovernor.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiTimelock.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract GovAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public proposer = address(0x3);
}

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

    constructor() {
        vm.startPrank(deployer);

        // deploy gov token via proxy
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
        calldatas[0] = "0x";

        vm.prank(proposer);
        vm.expectEmit(true, true, true, true, address(governor));
        emit ProposalCreated(
            21284495225446007869661364305915652377384362518400550250897600969950500894956,
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

}
