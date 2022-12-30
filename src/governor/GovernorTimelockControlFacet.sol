// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./GovernorStorage.sol";
import "./IGovernor.sol";
import "./IGovernorTimelockControl.sol";
import "./libGovernorCommon.sol";
import "@oz/governance/TimelockController.sol";

contract GovernorTimelockControlFacet is IGovernorTimelockControl {

    function timelock() public view returns (TimelockController) {
        return TimelockController(payable(GovernorStorage.configStorage().timelock));
    }

    // this function has overloaded behavior in the OZ contracts, acting as a
    // way to count down to execution as well as indicating if it was executed
    // or canceled. We don't need this overloaded functionality since we track
    // execution and cancellation globally in the GovernorStorage contract.
    function proposalEta(uint256 proposalId) external view override returns (uint256) {
        return GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp;
    }

    function queue(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external override returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);

        require(
            GovernorCommon.state(proposalId) == IGovernor.ProposalState.Succeeded, "Governor: proposal not successful"
        );

        uint256 delay = GovernorStorage.configStorage().votingDelay;
        GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp = block.timestamp + delay;

        timelock().scheduleBatch(targets, values, calldatas, 0, descriptionHash, delay);

        emit ProposalQueued(proposalId, block.timestamp + delay);

        return proposalId;
    }

    function execute(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external payable {
        require(GovernorCommon.state(proposalId) == IGovernor.ProposalState.Queued, "Governor: proposal not queued");
        timelock().executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);
    }

    function cancel(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) external returns (uint256) {
        uint256 proposalId = GovernorCommon.hashProposal(targets, values, calldatas, descriptionHash);
        IGovernor.ProposalState state = GovernorCommon.state(proposalId);

        require(
            state != IGovernor.ProposalState.Canceled && state != IGovernor.ProposalState.Expired
                && state != IGovernor.ProposalState.Executed,
            "Governor: proposal not queued"
        );

        GovernorStorage.proposalStorage().proposals[proposalId].canceled = true;
        emit ProposalCanceled(proposalId);

        if(GovernorStorage.proposalStorage().timelockQueue[proposalId].timestamp != 0) {
            bytes32 operationHash = timelock().hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
            timelock().cancel(operationHash);
            delete GovernorStorage.proposalStorage().timelockQueue[proposalId];
        }

        return proposalId;
    }

    function updateTimelock(address newTimelock) external override {
        address oldTimelock = GovernorStorage.configStorage().timelock;
        emit TimelockChange(oldTimelock, newTimelock);
        GovernorStorage.configStorage().timelock = newTimelock;
    }
}
