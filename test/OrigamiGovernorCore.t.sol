// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import "src/interfaces/IGovernor.sol";
import "src/interfaces/IGovernorQuorum.sol";
import "src/interfaces/IGovernorSettings.sol";
import "src/interfaces/IGovernorTimelockControl.sol";
import "src/interfaces/utils/IAccessControl.sol";
import "@diamond/interfaces/IERC165.sol";

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

contract OrigamiGovernorProposeBySigTest is GovernorDiamondHelper {
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
    uint8 public v;
    bytes32 public r;
    bytes32 public s;
    uint256 public nonce;
    string public description;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(origamiGovernorDiamond);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature("setGovernanceToken(address)", address(0xbad));
        signatures = new string[](1);

        // use the gov token for vote weight
        description = "Update the governance token.";

        v = 27;
        r = 0x4ba5e0c307c5e9d25f68f0a548955cf119206d273d4bcdb6dc876f3085b1dc67;
        s = 0x1a5722452f9f182f039bf5c86bdd1df1a1c13c0aae6bd7ada6ff7826e90bb04c;
        nonce = 0;
    }

    function testProposeBySig() public {
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCreated(
            37152077084267662562237225731447583962862989080556817955865322358291679988170,
            signingVoter,
            targets,
            values,
            signatures,
            calldatas,
            604842,
            1209642,
            description
            );
        coreFacet.proposeBySig(targets, values, calldatas, description, 0, v, r, s);
    }

    function testProposeWithParamsBySig() public {
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCreated(
            37152077084267662562237225731447583962862989080556817955865322358291679988170,
            signingVoter,
            targets,
            values,
            signatures,
            calldatas,
            604842,
            1209642,
            description
            );
        coreFacet.proposeWithParamsBySig(targets, values, calldatas, description, "", nonce, v, r, s);
    }

    function testProposeWithTokenAndCountingStrategyBySig() public {
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit ProposalCreated(
            37152077084267662562237225731447583962862989080556817955865322358291679988170,
            signingVoter,
            targets,
            values,
            signatures,
            calldatas,
            604842,
            1209642,
            description
            );
        coreFacet.proposeWithTokenAndCountingStrategyBySig(
            targets,
            values,
            calldatas,
            description,
            address(govToken),
            bytes4(keccak256("simpleWeight(uint256)")),
            nonce,
            v,
            r,
            s
        );
    }
}

contract OrigamiGovernorProposalVoteBySignatureTest is GovernorDiamondHelper {
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
        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectEmit(true, true, true, true, address(origamiGovernorDiamond));
        emit VoteCast(signingVoter, proposalId, FOR, 100000000, "I like it");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);
    }

    function testCanVoteOnProposalBySig() public {
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
        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newR = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, newR, s);
    }

    function testCannotVoteBySigWithBadS() public {
        // roll the block number forward to voting period
        vm.roll(604_843);
        bytes32 newS = 0x0000000000000000000000000000000000000000000000000000000000000000;
        vm.expectRevert("ECDSA: invalid signature");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, newS);
    }

    function testCannotVoteBySigWithBadV() public {
        // roll the block number forward to voting period
        vm.roll(604_843);
        vm.expectRevert("OrigamiGovernor: only members may vote");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, 27, r, s);
    }

    function testCannotReplayVote() public {
        // roll the block number forward to voting period
        vm.roll(604_843);
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);

        // cannot re-submit votes by signature
        vm.roll(604_844);
        vm.expectRevert("OrigamiGovernor: invalid nonce");
        coreFacet.castVoteWithReasonBySig(proposalId, FOR, "I like it", nonce, v, r, s);
    }
}
