// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev External interface of EIP712 declared to support ERC165 detection.
 * @author Origami
 */
interface IEIP712 {
    function name() external view returns (string memory);
    function version() external pure returns (string memory);
    function domainSeparatorV4() external view returns (bytes32);
}
