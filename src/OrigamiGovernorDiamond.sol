// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@diamond/Diamond.sol";
import "@diamond/interfaces/IDiamondCut.sol";

/**
 * @title The primary interface for Governance on the Origami platform.
 * @author Origami
 * @dev a simple derived contract that implements the EIP-2535 Diamond standard.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract OrigamiGovernorDiamond is Diamond {
    //solhint-disable-next-line no-empty-blocks
    constructor(address _contractOwner, address _diamondCutFacet) Diamond(_contractOwner, _diamondCutFacet) {}
}
