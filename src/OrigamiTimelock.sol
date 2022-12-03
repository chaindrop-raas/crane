// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

/// @title Origami Timelock
/// @author Stephen Caudill
/// @notice This contract implements a timelock mechanism for use alongside the OrigamiGovernor. It is a vanilla concrete implementation of TimelockControllerUpgradeable.
/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiTimelock is Initializable, TimelockControllerUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the timelock contract
     * @dev the only reason we need an implementation of this is so that the initializer is public, which lets us use it for deploying new OrigamiGovernor instances.
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors)
        public
        initializer
    {
        __TimelockController_init(minDelay, proposers, executors);
    }
}
