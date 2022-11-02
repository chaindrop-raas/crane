// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@oz-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

contract OrigamiTimelock is Initializable, TimelockControllerUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors
    ) public initializer {
        __TimelockController_init(_minDelay, _proposers, _executors);
    }
}
