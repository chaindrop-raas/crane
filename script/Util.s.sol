// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";
import "src/interfaces/IAccessControl.sol";

contract GrantPermissions is Script {
    bytes32 internal constant REVOKER_ROLE = 0xce3f34913921da558f105cefb578d87278debbbd073a8d552b5de0d168deee30;
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    function run(address target, address[] calldata accounts) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IAccessControl accessControl = IAccessControl(target);
        for (uint256 i = 0; i < accounts.length; i++) {
            accessControl.grantRole(REVOKER_ROLE, accounts[i]);
            accessControl.grantRole(MINTER_ROLE, accounts[i]);
        }

        vm.stopBroadcast();
    }
}
