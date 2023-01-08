// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/IGovernor.sol";
import "@diamond/Diamond.sol";
import "@diamond/interfaces/IDiamondCut.sol";

contract OrigamiGovernorDiamond is Diamond {
    //solhint-disable-next-line no-empty-blocks
    constructor(address _contractOwner, address _diamondCutFacet) Diamond(_contractOwner, _diamondCutFacet) {}
}
