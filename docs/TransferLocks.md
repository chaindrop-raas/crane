## General Information

The most important use case concepts in the `ITransferLocks` interface are as follows:

1. **Transfer Locks**: The interface provides functions to add transfer locks on tokens, restricting their transferability until a specified deadline. This feature is useful for scenarios where tokens need to be locked for a certain period, such as governance tokens with voting rights that cannot be transferred until a specific date.
2. **Allowance Management**: The interface includes functions to manage the allowance granted to another account for adding transfer locks on behalf of the caller. The `increaseTransferLockAllowance` and `decreaseTransferLockAllowance` functions allow the caller to increase or decrease the number of transfer locks that another account can add. This concept ensures control over who can add transfer locks and in what quantity.
3. **Total and Available Balances**: The interface provides functions to retrieve the total amount of tokens locked up and the available (unlocked) balance of an account. The `getTransferLockTotal` and `getAvailableBalance` functions return the locked and unlocked token amounts at the current block timestamp, respectively. The `getTransferLockTotalAt` and `getAvailableBalanceAt` functions allow querying balances at specific timestamps.
4. **Transfers with Locks**: The interface includes functions to transfer tokens while applying transfer locks. The `transferWithLock` function enables transferring tokens to a recipient while locking them until a specified deadline. The `batchTransferWithLocks` function allows for batch transfers to multiple recipients, each with their own lock amount and deadline.

These use case concepts collectively enable token transfer locking functionality, providing control over token transfers based on time restrictions, managing allowance for adding transfer locks, and querying locked and unlocked token balances for better transparency and control.

## Interface Description

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
2. `allowances`: Returns the number of transfer locks a recipient has permitted an account.
3. `decreaseTransferLockAllowance`: Decrease the number of transfer locks that can be added by another address.
4. `getTransferLockTotal`: Returns the total amount of locked tokens for an account at the current timestamp.
5. `getTransferLockTotalAt`: Returns the total amount of locked tokens for an account at a given timestamp.
6. `getAvailableBalance`: Returns the available (unlocked) balance for an account at the current timestamp.
7. `getAvailableBalanceAt`: Returns the available (unlocked) balance for an account at a given timestamp.
8. `increaseTransferLockAllowance`: Increase the number of transfer locks that can be added by another address.
9. `transferWithLock`: Transfers tokens to a recipient with a lock, which means the transferred tokens cannot be transferred again until the specified deadline.
10. `batchTransferWithLocks`: Allows for batch transfers with locks, transferring tokens to multiple recipients with different lock amounts and deadlines.

The `TransferLocks` contract also overrides the `_beforeTokenTransfer` function
of the `ERC20Base` contract to enforce transfer lock restrictions when
transferring tokens. This ensures that locked tokens cannot be transferred until
the specified deadlines have passed.


## Allowing Transfer Locks from Another Account

To allow another account to add transfer locks on your behalf, you need to use the `increaseTransferLockAllowance` function. This function increases the number of transfer locks that can be added by the specified address. Here's how to use it:

1. Call the `increaseTransferLockAllowance` function on the contract with `TransferLocks` enabled.
2. Pass the address of the account you want to allow as the first parameter (`account`).
3. Specify the number of additional transfer locks you want to allow as the second parameter (`amount`).

## Setting a Transfer Lock on an Account

To set a transfer lock on your own account, you can use the `addTransferLock` function. This function allows you to transfer a specified amount of tokens that cannot, in turn, be transferred until a given deadline has passed. Here's how to use it:

1. Call the `addTransferLock` function on the contract with `TransferLocks` enabled.
2. Specify the amount of tokens you want to lock as the first parameter (`amount`).
3. Set the deadline until which the tokens will be untransferrable as the second parameter (`deadline`). The deadline should be a Unix timestamp in UTC.
