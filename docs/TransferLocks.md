The **TransferLocks** module provides functionality to time-lock ERC20 token
transfers. This can be useful for implementing governance tokens with voting
rights that cannot be transferred until a certain date, for instance.

`TransferLocksStorage`, is a library used to store transfer locks. It defines a
storage data structure for transfer locks, which includes the amount locked, the
deadline (after which the lock expires), and pointers to the next and previous
locks in the list.

`TransferLocks` implements the `ITransferLocks` interface and provides the
following functionality:

1. `addTransferLock`: Allows a user to lock a specified amount of tokens until a given deadline.
2. `getTransferLockTotal`: Returns the total amount of locked tokens for an account at the current timestamp.
3. `getTransferLockTotalAt`: Returns the total amount of locked tokens for an account at a given timestamp.
4. `getAvailableBalanceAt`: Returns the available (unlocked) balance for an account at a given timestamp.
5. `transferWithLock`: Transfers tokens to a recipient with a lock, which means the transferred tokens cannot be transferred again until the specified deadline.
6. `batchTransferWithLocks`: Allows for batch transfers with locks, transferring tokens to multiple recipients with different lock amounts and deadlines.

The `TransferLocks` contract also overrides the `_beforeTokenTransfer` function
of the `ERC20Base` contract to enforce transfer lock restrictions when
transferring tokens. This ensures that locked tokens cannot be transferred until
the specified deadlines have passed.
