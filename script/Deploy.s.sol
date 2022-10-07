// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@std/Script.sol";
import "@std/Test.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script, Test {
    function membershipTokenFactory() public {
        OrigamiMembershipTokenFactory factoryImpl;
        TransparentUpgradeableProxy factoryProxy;
        OrigamiMembershipTokenFactory factory;
        ProxyAdmin factoryAdmin;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log(vm.addr(deployerPrivateKey));

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

        emit log_named_address("owner", owner);
        emit log_named_string("name", name);
        emit log_named_string("symbol", symbol);
        emit log_named_string("baseURI", baseURI);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        emit log_named_uint("deployer", deployerPrivateKey);

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
