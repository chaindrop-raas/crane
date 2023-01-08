// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library AccessControlStorage {
    bytes32 public constant ROLE_STORAGE_POSITION = keccak256("com.origami.accesscontrol.role");
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct RoleStorage {
        mapping(bytes32 => RoleData) roles;
    }

    function roleStorage() internal pure returns (RoleStorage storage rs) {
        bytes32 position = ROLE_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            rs.slot := position
        }
    }

    function roleData(bytes32 role) internal view returns (RoleData storage rd) {
        RoleStorage storage rs = roleStorage();
        rd = rs.roles[role];
    }

}
