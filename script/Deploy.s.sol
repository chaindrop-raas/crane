// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@std/Script.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    function membershipTokenFactory() public {
        OrigamiMembershipTokenFactory factoryImpl;
        TransparentUpgradeableProxy factoryProxy;
        OrigamiMembershipTokenFactory factory;
        ProxyAdmin factoryAdmin;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiMembershipTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiMembershipTokenFactory(address(factoryProxy));
        factory.initialize();

        vm.stopBroadcast();
    }

    function membershipToken(
        address owner,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) public {
        OrigamiMembershipToken impl;
        TransparentUpgradeableProxy proxy;
        OrigamiMembershipToken token;
        ProxyAdmin admin;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        admin = new ProxyAdmin();
        impl = new OrigamiMembershipToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );

        token = OrigamiMembershipToken(address(proxy));
        token.initialize(owner, name, symbol, baseURI);

        vm.stopBroadcast();
    }
}
