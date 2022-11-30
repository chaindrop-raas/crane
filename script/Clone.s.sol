// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

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

        OrigamiMembershipTokenFactory factory = OrigamiMembershipTokenFactory(factoryProxy);
        // slither-disable-next-line unused-return
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

        OrigamiGovernanceTokenFactory factory = OrigamiGovernanceTokenFactory(factoryProxy);
        // slither-disable-next-line unused-return
        factory.createOrigamiGovernanceToken(admin, name, symbol, supplyCap);

        vm.stopBroadcast();
    }
}
