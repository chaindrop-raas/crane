// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title Transfer Locks Storage Library
 * @author Origami
 * @notice This library is used to store transfer locks for the Origami Governance Token.
 * @custom:security-contact contract-security@joinorigami.com
 */
library TransferLocksStorage {
    bytes32 public constant TRANSFER_LOCKS_STORAGE_POSITION = keccak256("com.origami.transferlocks");

    /// @dev storage data structure for transfer locks
    struct TransferLock {
        uint256 amount;
        uint256 deadline;
    }

    /// @dev address mapping for transfer locks
    struct TransferLocks {
        mapping(address => TransferLock[]) locks;
    }

    /// @dev returns the storage pointer for transfer locks
    function transferLocksStorage() internal pure returns (TransferLocks storage tls) {
        bytes32 position = TRANSFER_LOCKS_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            tls.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    /**
     * @notice adds a transfer lock to an account
     * @param account the account to add the transfer lock to
     * @param amount the amount of tokens to lock
     * @param deadline the timestamp after which the lock expires
     */
    function addTransferLock(address account, uint256 amount, uint256 deadline) internal {
        TransferLocks storage tls = transferLocksStorage();
        tls.locks[account].push(TransferLock(amount, deadline));
    }

    /**
     * @notice returns the total amount of tokens locked for an account as of a given timestamp
     * @param account the account to check
     * @param timestamp the timestamp to check
     * @return the total amount of tokens locked for an account at the given timestamp
     */
    function getTotalLockedAt(address account, uint256 timestamp) internal view returns (uint256) {
        TransferLocks storage tls = transferLocksStorage();
        uint256 totalLocked = 0;
        for (uint256 i = 0; i < tls.locks[account].length; i++) {
            if (tls.locks[account][i].deadline >= timestamp) {
                totalLocked += tls.locks[account][i].amount;
            }
        }
        return totalLocked;
    }
}
