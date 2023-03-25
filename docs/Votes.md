This Votes module is designed to manage voting weight calculations for either
ERC20 or ERC721 tokens. It consists of two primary components: `Checkpoints` and
`Votes`. It also includes two interfaces: `IVotes` and `IVotesToken` which
detail the interface provided (`IVotes`) and the interface relied upon
(`IVotesToken`). Here's a high-level overview of each contract:

1. `IVotes`:
   This interface defines the functions exposed for managing and interrogating
   voting rights, such as getting votes for an account, getting past votes,
   getting past total supply, and delegation-related functions. Contracts that
   implement this interface will handle the core voting functionality of the
   governance system.
2. `IVotesToken`:
   This interface is a subset of the ERC20 and ERC721 token standards, making
   explicit which functions are required for the `Votes` library to function. It
   defines the basic functions for the token, namely `name`, `version`, and
   `balanceOf` for an account.
3. `Checkpoints`:
   This utility contract is responsible for the storage of historical voting
   data, enabling users to query past votes or total supply at a specific
   timestamp. It provides mechanisms to efficiently store and retrieve this
   data.
4. `Votes`:
   This abstract contract provides an implementation that interfaces with the
   storage mechanisms of `Checkpoints` and serves as the foundation for building
   a governance token with voting functionality. Contracts that inherit from
   this abstract contract gain access to a full suite of tools related to
   delegation and historical counts of voting weights.

By combining these contracts, the Votes module provides a robust framework for
managing voting weight calculations and delegation in conforming tokens. Any
contract that inherits from the Votes contract will need to implement the
`IVotesToken` interface and ensure it calls `Votes.transferVotingUnits` when
tokens are transferred (ideally from an after-transfer hook).
