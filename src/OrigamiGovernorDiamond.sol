// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/IGovernor.sol";
import "@diamond/Diamond.sol";
import "@diamond/interfaces/IDiamondCut.sol";
import "@oz/utils/introspection/ERC165.sol";

contract OrigamiGovernorDiamond is Diamond, ERC165 {
    //solhint-disable-next-line no-empty-blocks
    constructor(address _contractOwner, address _diamondCutFacet) Diamond(_contractOwner, _diamondCutFacet) {}

    function supportsInterface(bytes4 interfaceId) public view override (ERC165) returns (bool) {
        return interfaceId == type(IGovernor).interfaceId || interfaceId == type(IDiamondCut).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
