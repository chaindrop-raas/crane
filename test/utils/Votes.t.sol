// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Votes} from "src/utils/Votes.sol";
import {Test, console2} from "@std/Test.sol";

contract VotesTest is Votes {
    mapping(address => uint256) public balances;

    function mint(address account, uint256 amount) external {
        balances[account] += amount;
        transferVotingUnits(address(0), account, amount);
    }

    function balanceOf(address owner) external view override returns (uint256 balance) {
        return balances[owner];
    }

    function name() external pure override returns (string memory) {
        return "VotesTest";
    }

    function version() external pure override returns (string memory) {
        return "1";
    }
}

abstract contract VotesTestHelper is Test {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public recipient = address(0x3);

    VotesTest public votes;

    function setUp() public {
        vm.prank(owner);
        votes = new VotesTest();
    }
}

contract BaselineTest is VotesTestHelper {
    function testGetVotes() public {
        votes.mint(recipient, 100);
        assertEq(votes.getVotes(recipient), 0);

        vm.prank(recipient);
        votes.delegate(recipient);
        assertEq(votes.getVotes(recipient), 100);
    }

    function testGetPastVotes() public {
        vm.warp(42);
        votes.mint(recipient, 100);
        assertEq(votes.getVotes(recipient), 0);

        vm.prank(recipient);
        votes.delegate(recipient);
        assertEq(votes.getPastVotes(recipient, 1), 0);
        assertEq(votes.getPastVotes(recipient, 42), 100);
    }
}

contract QSP3VotesTest is VotesTestHelper {
    function testExploit() public {
        // Step 1.
        // address_1 which has a token balance of 100 and a voting power of 100.
        address accountOne = address(0x4);
        votes.mint(accountOne, 100);
        vm.prank(accountOne);
        votes.delegate(accountOne);
        assertEq(votes.getVotes(accountOne), 100);

        // address_2 which has a token balance of 100 and a voting power of 100.
        address accountTwo = address(0x5);
        votes.mint(accountTwo, 100);
        vm.prank(accountTwo);
        votes.delegate(accountTwo);
        assertEq(votes.getVotes(accountTwo), 100);

        // Step 2.
        // address_1 calls Votes.delegate(address_2)
        vm.prank(accountOne);
        votes.delegate(accountTwo);

        assertEq(votes.getVotes(accountOne), 0);
        assertEq(votes.getVotes(accountTwo), 200);

        // Step 3.
        // address_1 acquires 100 tokens
        votes.mint(accountOne, 100);

        assertEq(votes.balanceOf(accountOne), 200);
        assertEq(votes.getVotes(accountOne), 0);
        assertEq(votes.balanceOf(accountTwo), 100);
        assertEq(votes.getVotes(accountTwo), 300);

        // Step 4.
        // address_1 calls Votes.delegate(address_1)
        vm.prank(accountOne);
        votes.delegate(accountOne);

        assertEq(votes.balanceOf(accountOne), 200);
        assertEq(votes.getVotes(accountOne), 200);
        assertEq(votes.balanceOf(accountTwo), 100);
        assertEq(votes.getVotes(accountTwo), 100);
    }
}
