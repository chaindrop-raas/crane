// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernorDiamond.sol";
import "src/OrigamiMembershipToken.sol";

import "src/governor/GovernorCoreFacet.sol";
import "src/governor/GovernorSettingsFacet.sol";
import "src/governor/GovernorTimelockControlFacet.sol";
import "src/upgradeInitializers/GovernorDiamondInit.sol";
import "src/utils/DiamondDeployHelper.sol";

import "@std/Test.sol";

import "@diamond/facets/DiamondCutFacet.sol";
import "@diamond/facets/DiamondLoupeFacet.sol";
import "@diamond/facets/OwnershipFacet.sol";

import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract GovDiamondAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public admin = address(0x3);
    address public voter = address(0x4);
    address public voter2 = address(0x5);
    address public voter3 = address(0x6);
    address public voter4 = address(0x7);
    address public newVoter = address(0x8);
    address public nonMember = address(0x9);
    address public voterProxy = address(0xa);
    address public signingVoter = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
}

contract GovernorDiamondHelper is GovDiamondAddressHelper, Test {
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

    OrigamiGovernorDiamond public origamiGovernorDiamond;

    GovernorCoreFacet public coreFacet;
    GovernorSettingsFacet public settingsFacet;
    GovernorTimelockControlFacet public timelockControlFacet;

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

        GovernorDiamondInit diamondInit = new GovernorDiamondInit();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        cuts[0] = DiamondDeployHelper.diamondLoupeFacetCut(address(diamondLoupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        cuts[1] = DiamondDeployHelper.ownershipFacetCut(address(ownershipFacet));

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();

        // deploy timelock via proxy
        timelockAdmin = new ProxyAdmin();
        timelockImpl = new OrigamiTimelock();
        timelockProxy = new TransparentUpgradeableProxy(
            address(timelockImpl),
            address(timelockAdmin),
            ""
        );
        timelock = OrigamiTimelock(payable(timelockProxy));

        // initialize the timelock after we have an address for the governor
        address[] memory proposers = new address[](1);
        proposers[0] = address(governorCoreFacet);
        address[] memory executors = new address[](1);
        executors[0] = address(governorCoreFacet);

        timelock.initialize(1 days, proposers, executors);

        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(governorCoreFacet);

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(governorSettingsFacet);

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(governorTimelockControlFacet);

        origamiGovernorDiamond = new OrigamiGovernorDiamond(owner, address(diamondCutFacet));

        vm.stopPrank();

        vm.startPrank(owner);
        DiamondCutFacet(address(origamiGovernorDiamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeWithSignature(
                "init(string,address,address,address,uint24,uint24,uint8,uint16)",
                "TestGovernor",
                admin,
                address(timelock),
                address(memToken),
                7 days,
                7 days,
                10,
                1
            )
        );

        // issue the voters membership tokens
        memToken.safeMint(voter);
        memToken.safeMint(voter2);
        memToken.safeMint(voter3);
        memToken.safeMint(voter4);
        memToken.safeMint(newVoter);
        memToken.safeMint(signingVoter);

        // issue the voters gov tokens
        govToken.mint(voter, 100000000); // 10000^2
        govToken.mint(voter2, 225000000); // 15000^2
        govToken.mint(voter3, 56250000); // 7500^2
        govToken.mint(voter4, 306250000); // 17500^2
        govToken.mint(nonMember, 56250000);
        govToken.mint(signingVoter, 100000000);

        // mine, so that proposals snapshot after these mints.
        vm.roll(2);
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

        vm.roll(42);

        coreFacet = GovernorCoreFacet(address(origamiGovernorDiamond));
        settingsFacet = GovernorSettingsFacet(address(origamiGovernorDiamond));
        timelockControlFacet = GovernorTimelockControlFacet(address(origamiGovernorDiamond));
    }
}

contract OrigamiGovernorDiamondDeployTest is GovernorDiamondHelper {

    function testRetrieveGovernorName() public {
        assertEq(coreFacet.name(), "TestGovernor");
    }

    function testAdminHasDefaultAdminRole() public {
        assertTrue(coreFacet.hasRole(0x00, admin));
    }

    function testRetrieveProposalThreshold() public {
        assertEq(settingsFacet.proposalThreshold(), 1);
    }

    function testInformationalFunctions() public {
        assertEq(address(timelockControlFacet.timelock()), address(timelock));
        assertEq(coreFacet.name(), "TestGovernor");
        assertEq(settingsFacet.votingDelay(), 604_800);
        assertEq(coreFacet.version(), "1.1.0");
        assertEq(settingsFacet.votingPeriod(), 604_800);
        assertEq(settingsFacet.proposalThreshold(), 1);
        assertEq(settingsFacet.quorumNumerator(), 10);
    }

    function testEIP712DomainSeparator() public {
        // just to be clear about the external implementation of the domainSeparator:
        assertEq(
            coreFacet.domainSeparatorV4(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(coreFacet.name())),
                    keccak256(bytes(coreFacet.version())),
                    block.chainid,
                    address(origamiGovernorDiamond)
                )
            )
        );
    }
}

contract OrigamiGovernorProposalTest is GovernorDiamondHelper {
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

        vm.prank(voter2);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCreated(
            62912883481399652201384617016484797517292059425633292282859862689999298978076,
            voter2,
            targets,
            values,
            signatures,
            calldatas,
            604842,
            1209642,
            "New proposal"
            );
        coreFacet.propose(targets, values, calldatas, "New proposal");
    }

    function testCannotSubmitProposalWithZeroTargets() public {
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: empty proposal");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroValues() public {
        targets = new address[](1);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: invalid proposal length");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroCalldatas() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](0);
        vm.prank(voter2);
        vm.expectRevert("Governor: invalid proposal length");
        coreFacet.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitSameProposalTwice() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.startPrank(voter2);
        coreFacet.propose(targets, values, calldatas, "New proposal");
        vm.expectRevert("Governor: proposal already exists");
        coreFacet.propose(targets, values, calldatas, "New proposal");
    }

    function testProposalWithParamsTokenMustSupportIVotes() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.prank(voter2);
        vm.expectRevert("Governor: proposal token must support IVotes");
        coreFacet.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(timelock), bytes4(keccak256("simpleWeight(uint256)")))
        );
    }
}
