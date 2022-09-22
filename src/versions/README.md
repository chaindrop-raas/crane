# Contract Versions

This memorializes the prior versions that have been created.

| Filename                                                                  |   SHA   | Reason                                                                                             |
| :------------------------------------------------------------------------ | :-----: | :------------------------------------------------------------------------------------------------- |
| `contracts/versions/OrigamiGovernanceTokenTestVersion.sol`                | fa79b29 | Introduced to test upgrades to `OrigamiGovernanceToken`. See "upgrading" tests.                    |
| `contracts/versions/OrigamiMembershipTokenTestVersion.sol`                | 2ac09f5 | Introduced to test upgrades to `OrigamiMembershipToken`. See "upgrading" tests.                    |
| `contracts/versions/OrigamiMembershipTokenBeforeMintEvent.sol`            | 8acb2ab | Adhere to the expectation by our mint listener that we will emit a `Mint` event.                   |
| `contracts/versions/OrigamiGovernanceTokenBeforeTransferrer.sol`          | 15401be | Introduce `TRANSFERRER_ROLE` and allow it to make transfers regardless of transferability settings |
| `contracts/versions/OrigamiGovernanceTokenBeforeInitialAuditFeedback.sol` | 3ad9d5d | Address audit feedback                                                                             |
| `contracts/versions/OrigamiMembershipTokenBeforeInitialAuditFeedback.sol` | 3ad9d5d | Address audit feedback                                                                             |
