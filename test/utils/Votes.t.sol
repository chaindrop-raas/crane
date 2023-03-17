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

    function transfer(address recipient, uint256 amount) external {
        address sender = msg.sender;
        balances[sender] -= amount;
        balances[recipient] += amount;
        transferVotingUnits(sender, recipient, amount);
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

contract VotesCanAlwaysBeRecalledTest is VotesTestHelper {
    function testDelegationRevoke() public {
        /**
         * We want to ensure that when voting power has been
         * delegated and new tokens are introduced that the revoke
         * doesn't return more voting power than was originally delegated
         */

        // Given 1 exchange
        vm.prank(owner);
        address dex = address(0x42);
        votes.mint(dex, 200000);

        // Given two account each with voting power 100 and balance 100
        address accountOne = address(0x4);
        votes.mint(accountOne, 100);
        vm.prank(accountOne);
        votes.delegate(accountOne);
        assertEq(votes.getVotes(accountOne), 100);

        address accountTwo = address(0x5);
        votes.mint(accountTwo, 100);
        vm.prank(accountTwo);
        votes.delegate(accountTwo);
        assertEq(votes.getVotes(accountTwo), 100);

        // When accountOne delegates to accountTwo
        vm.prank(accountOne);
        votes.delegate(accountTwo);

        // Then all of accountOne's voting power becomes accountTwo's
        assertEq(votes.getVotes(accountOne), 0);
        assertEq(votes.getVotes(accountTwo), 200);

        // And neither of their balances change
        assertEq(votes.balanceOf(accountOne), 100);
        assertEq(votes.balanceOf(accountTwo), 100);

        // When we give accountOne more tokens
        vm.prank(dex);
        votes.transfer(accountOne, 100);

        // Then accountOne's balance is 200
        // And their voting power is still 0 because they have already
        // delegated their power

        assertEq(votes.balanceOf(accountOne), 200);
        assertEq(votes.getVotes(accountOne), 0);

        // And accountTwo has 100 additional voting power from accountOne
        assertEq(votes.balanceOf(accountTwo), 100);
        assertEq(votes.getVotes(accountTwo), 300);

        // When accountOne revokes their delegation to accountTwo
        vm.prank(accountOne);
        votes.delegate(accountOne);

        // Then they should both have the voting power of their token balance
        assertEq(votes.balanceOf(accountOne), 200);
        assertEq(votes.getVotes(accountOne), 200);

        // And accountTwo should have only it's balance worth of voting power
        assertEq(votes.balanceOf(accountTwo), 100);
        assertEq(votes.getVotes(accountTwo), 100);
    }
}

contract VoteDelegationTest is VotesTestHelper {
    function testDelegationIsNotTransitive() public {
        /**
         * NB: Delegation is not transitive. This means that if address_1
         * delegates to address_2 and address_2 delegates to address_3,
         * address_1 will not have delegated its weight to address_3.
         */

        // Given 2 accounts with balance 100 both self delegated
        address accountOne = address(0x4);
        votes.mint(accountOne, 100);
        vm.prank(accountOne);
        votes.delegate(accountOne);

        address accountTwo = address(0x5);
        votes.mint(accountTwo, 100);
        vm.prank(accountTwo);
        votes.delegate(accountTwo);

        // And 1 account with balance 0 also self delegated
        address accountThree = address(0x3);
        vm.prank(accountThree);
        votes.delegate(accountThree);

        // When accountTwo delegates to accountThree
        vm.prank(accountTwo);
        votes.delegate(accountThree);

        // Then all of accountTwo's voting power becomes accountThree's
        assertEq(votes.getVotes(accountTwo), 0);
        assertEq(votes.getVotes(accountThree), 100);

        // Then accountOne delegates to accountTwo
        vm.prank(accountOne);
        votes.delegate(accountTwo);

        // Then, because delegation is not transitent, accountThree
        // should still have voting power of 100
        assertEq(votes.getVotes(accountThree), 100);

        // And accountTwo should now have voting power of 100 from accountOne
        assertEq(votes.getVotes(accountTwo), 100);

        // And accountOne should not have any voting power
        assertEq(votes.getVotes(accountOne), 0);

        // When accountTwo transfers tokens to accountThree
        vm.prank(accountTwo);
        votes.transfer(accountThree, 100);

        // Then the previous voting power stays intack
        assertEq(votes.getVotes(accountOne), 0);
        assertEq(votes.getVotes(accountTwo), 100);
        assertEq(votes.getVotes(accountThree), 100);

        // When addressOne recalls their delegation vm.prank(accountOne);
        vm.prank(accountOne);
        votes.delegate(accountOne);

        // Then addressOne's voting power should be the same as their balance
        assertEq(votes.getVotes(accountOne), 100);

        // And addressTwo's voting power should be 0 because they are delegated to 3
        assertEq(votes.getVotes(accountTwo), 0);
    }
}
