// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernorDiamond.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiTimelockController.sol";

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

    uint8 public constant FOR = uint8(SimpleCounting.VoteType.For);
    uint8 public constant AGAINST = uint8(SimpleCounting.VoteType.Against);
    uint8 public constant ABSTAIN = uint8(SimpleCounting.VoteType.Abstain);
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

    OrigamiTimelockController public timelock;

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

        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(governorCoreFacet);

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(governorSettingsFacet);

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(governorTimelockControlFacet);

        origamiGovernorDiamond = new OrigamiGovernorDiamond(owner, address(diamondCutFacet));

        // initialize the timelock after we have an address for the diamond
        address[] memory proposers = new address[](1);
        proposers[0] = address(origamiGovernorDiamond);
        address[] memory executors = new address[](1);
        executors[0] = address(origamiGovernorDiamond);

        // deploy the timelock
        timelock = new OrigamiTimelockController(1 days, proposers, executors);

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

        coreFacet = GovernorCoreFacet(address(origamiGovernorDiamond));
        settingsFacet = GovernorSettingsFacet(address(origamiGovernorDiamond));
        timelockControlFacet = GovernorTimelockControlFacet(address(origamiGovernorDiamond));
        loupeFacet = DiamondLoupeFacet(address(origamiGovernorDiamond));

        vm.prank(address(timelock));
        settingsFacet.setGovernanceToken(address(govToken));

        vm.roll(42);
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

    function testProposalWithParamsTokenMustBeAConfiguredToken() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // deploy another gov token via proxy
        ProxyAdmin diffGovTokenAdmin = new ProxyAdmin();
        OrigamiGovernanceToken diffGovTokenImpl = new OrigamiGovernanceToken();
        TransparentUpgradeableProxy diffGovTokenProxy = new TransparentUpgradeableProxy(
            address(diffGovTokenImpl),
            address(diffGovTokenAdmin),
            ""
        );
        OrigamiGovernanceToken diffGovToken = OrigamiGovernanceToken(address(diffGovTokenProxy));
        diffGovToken.initialize(owner, "Deciduous Tree Fellowship", "DTF", 10000000000000000000000000000);

        vm.prank(voter2);
        vm.expectRevert("Governor: proposal token not allowed");
        coreFacet.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(diffGovToken), bytes4(keccak256("simpleWeight(uint256)")))
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
        emit VoteCast(voter, proposalId, AGAINST, 1, "");
        coreFacet.castVote(proposalId, AGAINST);
    }

    function testCanVoteOnProposalWithParams() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");
    }

    function testAddressWithoutMembershipTokenCanDelegateToMember() public {
        // self-delegate to get voting power
        vm.prank(nonMember);
        govToken.delegate(newVoter);

        vm.roll(604_843);
        vm.prank(newVoter);

        // newVoter has the weight of nonMember's delegated tokens
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(newVoter, proposalId, AGAINST, 56250000, "I vote with their weight!");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I vote with their weight!");
    }

    function testRedelegatingDoesNotAffectCurrentProposals() public {
        // voter delegates voting power to voter2
        vm.prank(voter);
        govToken.delegate(voter2);

        // voter2 votes with delegated power
        vm.roll(604_843);
        vm.prank(voter2);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");

        // voter Redelegates to self
        vm.roll(604_844);
        vm.prank(voter);
        govToken.delegate(voter);

        // voter attempts to vote with their own power
        vm.roll(604_845);
        vm.prank(voter);
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it");
    }

    function testCanLimitVotingByWeight() public {
        // self-delegate to get voting power
        vm.prank(newVoter);
        govToken.delegate(newVoter);

        vm.roll(604_843);
        vm.prank(newVoter);

        // newVoter has correctly self-delegated, but their weight is zero
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");
    }

    function testCanLimitVotingToMembershipTokenHolders() public {
        vm.roll(604_843);
        vm.prank(address(0x2a23));

        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");
    }

    function testCanReviseVote() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it");

        // our voting system allows us to change our vote at any time,
        // regardless of the value of hasVoted
        assertEq(coreFacet.hasVoted(proposalId, voter), true);

        vm.roll(604_844);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, AGAINST, 100000000, "I no longer like it");
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I no longer like it");

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
        r = 0x4d22d95982621b207f482d7ed1d52ce0ec0bca6276be2d221d1b9a09988aedae;
        s = 0x1496ed0ad3410a751db21e575d98a00f2d2da5a66d855bc7a0722b578216b6dd;
        nonce = 0;
    }

    function testCanVoteOnProposalWithReasonBySig() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);
    }

    function testCanVoteOnProposalBySig() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // signature updated to reflect empty reason
        uint8 newV = 27;
        bytes32 newR = 0x28ddce5ed6018161b74a41314e1e97ac39e18f2b06d2af01020430d4a5d12423;
        bytes32 newS = 0x41d1ecf448b2c62fc807b9e412a81a04dc440e8bd360c9054b50f3e166f69cb5;

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, FOR, 100000000, "");
        coreFacet.castVoteBySig(proposalId, FOR, nonce, newV, newR, newS);
    }

    function testCanUpdateVoteOnProposalWithParamsBySignature() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);

        // roll forward to the next block
        vm.roll(604_844);
        // signature updated to reflect new nonce and changed vote/reason
        uint8 newV = 27;
        bytes32 newR = 0x4551adb0883cc8316d33a1b7899e03da39d0dcf13cca960264f933cd10b48d21;
        bytes32 newS = 0x6536c9a892fdcdc416b8d5a11a5f66a7bdc08f2e3411ff8acad66e23c8d2636c;
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, AGAINST, 100000000, "I no longer like it");
        coreFacet.castVoteWithReasonBySig(proposalId, AGAINST, "I no longer like it", 1, newV, newR, newS);
    }

    function testCannotVoteBySigWithBadR() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newR = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, newR, s);
    }

    function testCannotVoteBySigWithBadS() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newS = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, newS);
    }

    function testCannotVoteBySigWithBadV() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, 27, r, s);
    }

    function testCannotReplayVote() public {
        // self-delegate to get voting power
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        // roll the block number forward to voting period
        vm.roll(604_843);
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);

        // cannot re-submit votes by signature
        vm.roll(604_844);
        vm.expectRevert("OrigamiGovernor: invalid nonce");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);
    }
}

contract OrigamiGovernorProposalQuorumTest is GovernorDiamondHelper {
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
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testUnreachedQuorumDefeatsProposal() public {
        // travel to proposal voting period completion
        vm.roll(604_843 + 604_800);
        assertEq(coreFacet.quorum(proposalId), 84375000);
        // there have been no votes, so quorum will not be reached and state will be Defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumButDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.roll(604_843);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, AGAINST, "I don't like it.");

        // travel to proposal voting period completion
        vm.roll(604_843 + 604_800);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = coreFacet.proposalVotes(proposalId);
        assertGt(againstVotes, forVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumAndSucceeded() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.roll(604_843);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it.");

        // travel to proposal voting period completion
        vm.roll(604_843 + 604_800);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = coreFacet.proposalVotes(proposalId);
        assertGt(forVotes, againstVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    }
}

contract OrigamiGovernorProposalQuadraticVoteTest is GovernorDiamondHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

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
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithQuadraticCounting() public {
        // self-delegate to get voting power
        vm.startPrank(voter);
        govToken.delegate(voter);

        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(voter, proposalId, FOR, 100000000, "I like it!");
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it!");
    }
}

contract OrigamiGovernorProposalQuadraticVoteResultsTest is GovernorDiamondHelper {
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
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "Quadratic Proposal", params);
    }

    function testQuadraticVotingResultsAreCorrect() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // set block to first eligible voting block
        vm.roll(604_843);

        // voter and voter2 collectively have fewer tokens than voter3 by
        // themselves, but quadratic weighting has the effect of making them
        // more powerful together than voter3 alone

        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it!");

        vm.prank(voter2);
        coreFacet.castVoteWithReason(proposalId, AGAINST, "This is rubbish!");

        vm.prank(voter3);
        coreFacet.castVoteWithReason(proposalId, FOR, "I like it too! It's not rubbish at all!");

        vm.prank(voter4);
        coreFacet.castVoteWithReason(proposalId, ABSTAIN, "I have no opinion.");

        vm.roll(640_483 + 604_800);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = coreFacet.proposalVotes(proposalId);

        assertEq(againstVotes, 15000);
        assertEq(forVotes, 17500);
        assertEq(abstainVotes, 17500);
    }
}

contract OrigamiGovernorSimpleCounting is GovernorDiamondHelper {
    function testCannotSpecifyInvalidWeightStrategy() public {
        vm.expectRevert("Governor: weighting strategy not found");
        SimpleCounting.applyWeightStrategy(100, bytes4(keccak256("blahdraticWeight(uint256)")));
    }
}

contract OrigamiGovernorLifeCycleTest is GovernorDiamondHelper {
    event ProposalCanceled(uint256 proposalId);
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

    function testCanTransitionProposalThroughToExecution() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(604_843);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(604_843 + 604_800);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // console2.log("PR", Strings.toHexString(uint256(timelock.PROPOSER_ROLE())), 32);

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // the TimelockController cares about the block timestamp, so we need to warp in addition to roll
        // advance block timestamp so that it's after the proposal's required queuing time
        vm.warp(604_801);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalExecuted(proposalId);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        // advance to the the next block
        vm.roll(604_843 + 604_801);

        // proposal is in the executed state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function testCanTransitionProposalThroughToCancellation() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(604_843);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(604_843 + 604_800);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // grant the diamond the CANCELLER_ROLE
        vm.startPrank(deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(origamiGovernorDiamond));
        vm.stopPrank();

        vm.startPrank(admin);
        // grant the admin the CANCELLER_ROLE
        coreFacet.grantRole(coreFacet.CANCELLER_ROLE(), admin);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCanceled(proposalId);
        timelockControlFacet.cancel(targets, values, calldatas, proposalHash);
        vm.stopPrank();

        // advance to the the next block
        vm.roll(604_843 + 604_801);

        // proposal is in the canceled state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function testCannotQueueIfProposalIsDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(604_843);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 0, "I Don't like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(604_843 + 604_800);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));

        vm.expectRevert("Governor: proposal not successful");
        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
    }
}

contract OrigamiGovernorConfigTest is GovernorDiamondHelper {

    function testCannotDirectlyUpdateGovernanceToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setGovernanceToken(address(0));
    }

    function testCannotDirectlyUpdateMembershipToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setMembershipToken(address(0));
    }

    function testCannotDirectlyUpdateProposalThreshold() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThreshold(0);
    }

    function testCannotDirectlyUpdateProposalThresholdToken() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setProposalThresholdToken(address(0));
    }

    function testCannotDirectlyUpdateQuorumNumerator() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setQuorumNumerator(0);
    }

    function testCannotDirectlyUpdateVotingDelay() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingDelay(0);
    }

    function testCannotDirectlyUpdateVotingPeriod() public {
        vm.expectRevert("Governor: onlyGovernance");
        settingsFacet.setVotingPeriod(0);
    }

    function testTimelockCanUpdateGovernanceToken() public {
        vm.prank(address(timelock));
        settingsFacet.setGovernanceToken(address(0xbeef));
    }

    function testTimelockCanUpdateMembershipToken() public {
        vm.prank(address(timelock));
        settingsFacet.setMembershipToken(address(0xbeef));
    }

    function testTimelockCanUpdateProposalThreshold() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThreshold(0);
    }

    function testTimelockCanUpdateProposalThresholdToken() public {
        vm.prank(address(timelock));
        settingsFacet.setProposalThresholdToken(address(0xbeef));
    }

    function testTimelockCanUpdateQuorumNumerator() public {
        vm.prank(address(timelock));
        settingsFacet.setQuorumNumerator(0);
    }

    function testTimelockCanUpdateVotingDelay() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingDelay(0);
    }

    function testTimelockCanUpdateVotingPeriod() public {
        vm.prank(address(timelock));
        settingsFacet.setVotingPeriod(0);
    }
}

contract OrigamiGovernorUpdateSettingsViaProposal is GovernorDiamondHelper {
    OrigamiGovernanceToken public newGovTokenImpl;
    TransparentUpgradeableProxy public newGovTokenProxy;
    OrigamiGovernanceToken public newGovToken;
    ProxyAdmin public newGovTokenAdmin;

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        // deploy gov token via proxy
        newGovTokenAdmin = new ProxyAdmin();
        newGovTokenImpl = new OrigamiGovernanceToken();
        newGovTokenProxy = new TransparentUpgradeableProxy(
            address(newGovTokenImpl),
            address(newGovTokenAdmin),
            ""
        );
        newGovToken = OrigamiGovernanceToken(address(newGovTokenProxy));
        newGovToken.initialize(owner, "Deciduous Tree Governance Token", "DTGT", 10000000000000000000000000000);

        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("setGovernanceToken(address)", address(newGovToken));

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        vm.prank(voter2);
        proposalId = coreFacet.proposeWithParams(targets, values, calldatas, "New proposal", params);

        vm.deal(address(timelock), 1 ether);
    }

    function testUpdateGovernanceTokenViaProposal() public {
        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), address(govToken));

        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // advance to the voting period
        vm.roll(604_843);
        vm.prank(voter);
        coreFacet.castVoteWithReason(proposalId, 1, "I like it");

        // proposal is in the active state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(604_843 + 604_800);

        // proposal is in the succeeded state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        timelockControlFacet.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // the TimelockController cares about the block timestamp, so we need to warp in addition to roll
        // advance block timestamp so that it's after the proposal's required queuing time
        vm.warp(604_801);
        timelockControlFacet.execute(targets, values, calldatas, proposalHash);

        // advance past the execution delay
        vm.roll(604_843 + 604_801);

        // proposal is in the executed state
        assertEq(uint8(coreFacet.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

        // check that the governance token has been updated
        assertEq(settingsFacet.governanceToken(), address(newGovToken));
    }
}
