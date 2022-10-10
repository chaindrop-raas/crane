// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@std/Script.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";

contract Clone is Script {
    function cloneMembershipToken(
        address factoryProxy,
        address admin,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OrigamiMembershipTokenFactory factory = OrigamiMembershipTokenFactory(
            factoryProxy
        );
        factory.createOrigamiMembershipToken(admin, name, symbol, baseURI);

        vm.stopBroadcast();
    }
}
