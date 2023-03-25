The **OrigamiGovernanceToken** is an ERC20 token designed specifically for DAO governance functions within the Origami platform and ecosystem. It inherits from the `ERC20Base`, `TransferLocks`, and `Votes` contracts, which provide additional functionality for transfer locks and voting.

The `OrigamiGovernanceToken` contract overrides several functions from the base contracts to ensure compatibility and the correct application of transfer locks and voting rights. It provides the following features:

1. Implements the `IVotes` and `IVotesToken` interfaces for voting weight
  calculation and delegation.
2. Integrates the `TransferLocks` module to allow time-locked token transfers.
3. Overrides the `transferFrom` and `transfer` functions to enforce the
  `whenTransferrable` modifier, which controls whether transfers are globally
  enabled or not. This is useful for governance tokens that have limited
  transferability outside direct distribution from a DAO, ensuring they cannot
  be considered securities.
4. Overrides the `_beforeTokenTransfer` function to properly handle transfer
  lock restrictions during token transfers.
5. Overrides the `_afterTokenTransfer` function to correctly update voting units
  after a token transfer.

The `OrigamiGovernanceToken` contract is designed to be an integral part of the Origami platform's governance system, allowing token holders to participate in the decision-making process while ensuring that tokens are securely locked according to specified rules and have controlled transferability.
