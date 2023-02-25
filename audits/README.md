# Audits

This document correlates audit versions with code commits.

| Audit Date | Commit SHA                               | Audit File                                                              |
| :--------- | :--------------------------------------- | :---------------------------------------------------------------------- |
| 2022-06-29 | c7d7c45a66819bfc853a880245efc7e5d021bc00 | `audits/2022-06-29_Origami_Quantstamp_Audit_Final_Report.pdf`           |
| 2023-02-24 | 0b9576ac8de2e841cf88286d9f694a47472091c3 | `audits/2023-02-24_Origami_Quantstamp_Audit_ERC20Base_Final_Report.pdf` |

# 2022-06-29 Audit/Repository Commit Version discrepancy explained

This repository was recreated in October of 2022 and reimplemented using [foundry](https://getfoundry.sh). The switch from Hardhat to Foundry was most readily done by creating a new repository. The unfortunate side effect of creating a new repository is that we lost the history from the old repository and that some non-substantive changes took place that are not covered in the audit dated 2022-06-29. The codebase has been tagged [`snapshot-closest-to-audit-2022-06-29`](https://github.com/JoinOrigami/crane/tree/snapshot-closest-to-audit-2022-06-29) (aka `c7d7c45`) to readily identify the changes that took place between that point and the date of the audit. As of that commit, only import paths had been changed; no substantive changes had been made. For independent verification please compare `JoinOrigami/crane-old@9fec464:conctracts/*.sol` with `JoinOrigami/crane@c7d7c45:src/*.sol`.

# 2023-02-24 Audit Scope

This audit only covers our stripped-down `ERC20Base` contract located at `src/token/governance/ERC20Base.sol`. This contract is very simple and is suitable for use as a basic upgradeable ERC20 with minimal governance functionality. We use this minimal contract as part of an L1 deployment that is paired with an L2 deployment over a bridge. NatSpec documentation has since been updated to address the "Medium" documentation score in the audit.
