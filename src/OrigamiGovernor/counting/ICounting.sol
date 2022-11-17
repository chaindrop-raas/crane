// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICounting {
    function countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) external returns (uint256);
}
