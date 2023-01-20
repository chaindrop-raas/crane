// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

import "src/governor/lib/TokenWeightStrategy.sol";
import "@std/Test.sol";

contract TokenWeightStrategyTest is Test {
    bytes4 internal constant simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
    bytes4 internal constant quadraticWeightSelector = bytes4(keccak256("quadraticWeight(uint256)"));

    function testApplyStrategySimple() public {
        assertEq(TokenWeightStrategy.applyStrategy(100, simpleWeightSelector), 100);
        assertEq(TokenWeightStrategy.applyStrategy(50, simpleWeightSelector), 50);
        assertEq(TokenWeightStrategy.applyStrategy(0, simpleWeightSelector), 0);
    }

    function testApplyStrategyQuadratic() public {
        assertEq(TokenWeightStrategy.applyStrategy(10000, quadraticWeightSelector), 100);
        assertEq(TokenWeightStrategy.applyStrategy(2500, quadraticWeightSelector), 50);
        assertEq(TokenWeightStrategy.applyStrategy(0, quadraticWeightSelector), 0);
    }

    function testSimpleWeight() public {
        assertEq(TokenWeightStrategy.simpleWeight(100), 100);
        assertEq(TokenWeightStrategy.simpleWeight(50), 50);
        assertEq(TokenWeightStrategy.simpleWeight(0), 0);
    }

    function testQuadraticWeight() public {
        assertEq(TokenWeightStrategy.quadraticWeight(10000), 100);
        assertEq(TokenWeightStrategy.quadraticWeight(2500), 50);
        assertEq(TokenWeightStrategy.quadraticWeight(0), 0);
    }
}
