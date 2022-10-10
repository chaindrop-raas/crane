// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@std/Script.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernanceTokenFactory.sol";

contract Clone is Script {
    function cloneMembershipToken(
        address factoryProxy,
        address admin,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OrigamiMembershipTokenFactory factory = OrigamiMembershipTokenFactory(
            factoryProxy
        );
        factory.createOrigamiMembershipToken(admin, name, symbol, baseURI);

        vm.stopBroadcast();
    }

    function cloneGovernanceToken(
        address factoryProxy,
        address admin,
        string calldata name,
        string calldata symbol,
        uint256 supplyCap
    ) public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OrigamiGovernanceTokenFactory factory = OrigamiGovernanceTokenFactory(
            factoryProxy
        );
        factory.createOrigamiGovernanceToken(admin, name, symbol, supplyCap);

        vm.stopBroadcast();
    }
}
