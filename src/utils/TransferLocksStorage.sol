// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library TransferLocksStorage {
    bytes32 public constant TRANSFER_LOCKS_STORAGE_POSITION = keccak256("com.origami.transferlocks");

    struct TransferLock {
        uint256 amount;
        uint256 deadline;
    }

    struct TransferLocks {
        mapping(address => TransferLock[]) locks;
    }

    function transferLocksStorage() internal pure returns (TransferLocks storage tls) {
        bytes32 position = TRANSFER_LOCKS_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            tls.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    function addTransferLock(address account, uint256 amount, uint256 deadline) internal {
        TransferLocks storage tls = transferLocksStorage();
        tls.locks[account].push(TransferLock(amount, deadline));
    }

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
