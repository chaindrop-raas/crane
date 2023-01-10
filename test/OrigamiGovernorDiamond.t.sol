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

import "src/interfaces/IGovernor.sol";
import "src/interfaces/IGovernorTimelockControl.sol";
import "src/interfaces/utils/IAccessControl.sol";

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

    DiamondLoupeFacet public loupeFacet;
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
        loupeFacet = DiamondLoupeFacet(address(origamiGovernorDiamond));
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

    function testSupportsInterface() public {
        assertTrue(loupeFacet.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(loupeFacet.supportsInterface(type(IERC165).interfaceId));
        assertTrue(loupeFacet.supportsInterface(type(IGovernor).interfaceId));
        assertTrue(loupeFacet.supportsInterface(type(IGovernorQuorum).interfaceId));
        assertTrue(loupeFacet.supportsInterface(type(IGovernorSettings).interfaceId));
        assertTrue(loupeFacet.supportsInterface(type(IGovernorTimelockControl).interfaceId));
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

contract OrigamiGovernorProposalVoteTest is GovernorDiamondHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithDefaultParams() public {
        vm.startPrank(voter);
        proposalId = coreFacet.propose(targets, values, calldatas, "Simple Voting Proposal");
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        // our voting weight is 1 here, since this vote uses the membership token
        emit VoteCast(voter, proposalId, 0, 1, "");
        coreFacet.castVote(proposalId, 0);
    }

    function testCanVoteOnProposalWithParams() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, 1, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");
    }

    function testAddressWithoutMembershipTokenCanDelegateToMember() public {
        // self-delegate to get voting power
        vm.prank(nonMember);
        govToken.delegate(newVoter);

        vm.roll(604_843);
        vm.prank(newVoter);

        // newVoter has the weight of nonMember's delegated tokens
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(newVoter, proposalId, 0, 56250000, "I vote with their weight!");
        coreFacet.castVoteWithReason(proposalId, 0, "I vote with their weight!");
    }

    function testRedelegatingDoesNotAffectCurrentProposals() public {
        // voter delegates voting power to voter2
        vm.prank(voter);
        govToken.delegate(voter2);

        // voter2 votes with delegated power
        vm.roll(604_843);
        vm.prank(voter2);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // voter Redelegates to self
        vm.roll(604_844);
        vm.prank(voter);
        govToken.delegate(voter);

        // voter attempts to vote with their own power
        vm.roll(604_845);
        vm.prank(voter);
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, 0, "I don't like it");
    }

    function testCanLimitVotingByWeight() public {
        // self-delegate to get voting power
        vm.prank(newVoter);
        govToken.delegate(newVoter);

        vm.roll(604_843);
        vm.prank(newVoter);

        // newVoter has correctly self-delegated, but their weight is zero
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, 0, "I don't like it.");
    }

    function testCanLimitVotingToMembershipTokenHolders() public {
        vm.roll(604_843);
        vm.prank(address(0x2a23));

        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReason(proposalId, 0, "I don't like it.");
    }

    function testCanReviseVote() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, 1, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // our voting system allows us to change our vote at any time,
        // regardless of the value of hasVoted
        assertEq(coreFacet.hasVoted(proposalId, voter), true);

        vm.roll(604_844);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, 0, 100000000, "I no longer like it");
        coreFacet.castVoteWithReason(proposalId, 0, "I no longer like it");

        assertEq(coreFacet.hasVoted(proposalId, voter), true);
    }
}

contract OrigamiGovernorProposalVoteWithSignatureTest is GovernorDiamondHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;
    uint8 public v;
    bytes32 public r;
    bytes32 public s;
    uint256 public nonce;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);

        // These values were derived by using this signing scheme:
        // https://gist.github.com/mrmemes-eth/c308260a72563b8f3c568d131c272033
        // the signer is anvil address 0: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
        v = 28;
        r = 0xed6434d453be27288943d6459b0884e9e3dd6331817fe43243f07658508ba31e;
        s = 0x715e1acc271986d24eb2bbfff1e9eb56f715d623704e077a947c5c6f2c4bb2a1;
        nonce = 0;
    }

    function testCanVoteOnProposalWithReasonBySig() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, 1, 100000000, "I like it");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, r, s);
    }

    function testCanVoteOnProposalBySig() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // signature updated to reflect empty reason
        uint8 newV = 27;
        bytes32 newR = 0x075ee72fb65c543c277eb40fd4030cd9da44801f11219120187930e5bc14f794;
        bytes32 newS = 0x69a5212721a2768adb92fb10e3f02fca5666888d299e99fb4fd9021b9cb1c72d;

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, 1, 100000000, "");
        coreFacet.castVoteBySig(proposalId, 1, nonce, newV, newR, newS);
    }

    function testCanUpdateVoteOnProposalWithParamsBySignature() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, 1, 100000000, "I like it");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, r, s);

        // roll forward to the next block
        vm.roll(604_844);
        // signature updated to reflect new nonce and changed vote/reason
        uint8 newV = 27;
        bytes32 newR = 0x612f7cbfeecc12031b3c7c5c14663559b494e73d4157ff4e7db7112dccea79b4;
        bytes32 newS = 0x366c7e8a43577c6edda0ce44fe3b3e4a32acca0c6101d47a84ba6cc03c057946;
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, 0, 100000000, "I no longer like it");
        coreFacet.castVoteWithReasonBySig(proposalId, 0, "I no longer like it", 1, newV, newR, newS);
    }

    function testCannotVoteBySigWithBadR() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newR = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, newR, s);
    }

    function testCannotVoteBySigWithBadS() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newS = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, r, newS);
    }

    function testCannotVoteBySigWithBadV() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, 27, r, s);
    }

    function testCannotReplayVote() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, r, s);

        // cannot re-submit votes by signature
        vm.roll(604_844);
        vm.expectRevert("OrigamiGovernor: invalid nonce");
        coreFacet.castVoteWithReasonBySig(proposalId, 1, "I like it", nonce, v, r, s);
    }
}
