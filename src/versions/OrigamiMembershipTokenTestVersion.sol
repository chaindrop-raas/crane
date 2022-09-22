// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// This contract is test-only and will not be deployed
import "../OrigamiMembershipToken.sol";

/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiMembershipTokenTestVersion is OrigamiMembershipToken {
    function isFromUpgrade() public pure returns (bool) {
        return true;
    }
}
