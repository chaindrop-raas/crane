//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact contract-security@joinorigami.com
 */
library TokenWeightStrategy {
    bytes4 internal constant simpleWeightSelector = bytes4(keccak256("simpleWeight(uint256)"));
    bytes4 internal constant quadraticWeightSelector = bytes4(keccak256("quadraticWeight(uint256)"));

    /**
     * @notice Applies the indicated weighting strategy to the amount `weight` that is supplied.
     * @dev the staticcall is only executed against this contract and is checked for success before failing to a revert if the selector isn't found on this contract.
     * @param weight the token weight to apply the weighting strategy to.
     * @param weightingSelector an encoded selector to use as a weighting strategy implementation.
     * @return the weight with the weighting strategy applied to it.
     */
    function applyStrategy(uint256 weight, bytes4 weightingSelector) internal pure returns (uint256) {
        // We check for success and only issue this as staticcall

        if (weightingSelector == simpleWeightSelector) {
            return simpleWeight(weight);
        } else if (weightingSelector == quadraticWeightSelector) {
            return quadraticWeight(weight);
        } else {
            revert("Governor: weighting strategy not found");
        }
    }

    /**
     * @notice simple weight calculation does not apply any weighting strategy. It is an integer identity function.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function simpleWeight(uint256 weight) internal pure returns (uint256) {
        return weight;
    }

    /**
     * @notice quadratic weight calculation returns square root of the weight.
     * @param weight the weight to apply the weighting strategy to.
     * @return the weight with the weighting strategy applied to it.
     */
    function quadraticWeight(uint256 weight) internal pure returns (uint256) {
        return squareRoot(weight);
    }

    /**
     * @dev square root algorithm from https://github.com/ethereum/dapp-bin/pull/50#issuecomment-1075267374
     * @param x the number to derive the square root of.
     * @return y - the square root of x.
     */
    function squareRoot(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
