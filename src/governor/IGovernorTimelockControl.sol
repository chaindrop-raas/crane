// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@oz/governance/TimelockController.sol";

interface IGovernorTimelockControl {
    event TimelockChange(address oldTimelock, address newTimelock);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalCanceled(uint256 proposalId);

    function timelock() external view returns (TimelockController);

    function proposalEta(uint256 proposalId) external view returns (uint256);

    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    function updateTimelock(address newTimelock) external;
}
