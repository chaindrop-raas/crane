// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {GovernorDiamondHelper} from "test/OrigamiDiamondTestHelper.sol";

contract TimelockControlFacetTest is GovernorDiamondHelper {
    function testInformationalFunctions() public {
        assertEq(address(timelockControlFacet.timelock()), address(timelock));
    }

}
