// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface ITransferLocks {
    /**
     * @notice Used to voluntarily lock up `amount` tokens until a given time. Tokens in excess of `amount` may be transferred.
     * @dev Block timestamp may be innaccurate by up to 15 minutes, but on a timescale of years this is negligible.
     * @param amount the amount of tokens to restrict the transfer of.
     * @param deadline the date (as a unix timestamp in UTC) until which amount will be untransferrable.
     */
    function addTransferLock(uint256 amount, uint256 deadline) external;

    /**
     * @notice Check the lockup details for an address. Returns 0 if there is no registered lockup.
     * @param account the address to check.
     * @return amount the amount of tokens locked.
     */
    function getTransferLockTotal(address account) external view returns (uint256 amount);

    /**
     * @notice Check the lockup details for an address as of a given timestamp. Returns 0 if there is no registered lockup.
     * @param account the address to check.
     * @param timestamp the timestamp to check.
     * @return amount the amount of tokens locked.
     */
    function getTransferLockTotalAt(address account, uint256 timestamp) external view returns (uint256 amount);

    /**
     * @notice Retrieves the balance of an account that is not locked at a given timestamp.
     * @param account the address to check.
     * @param timestamp the timestamp to check.
     * @return amount the amount of tokens that are not transfer-locked.
     */
    function getAvailableBalanceAt(address account, uint256 timestamp) external view returns (uint256 amount);
}
