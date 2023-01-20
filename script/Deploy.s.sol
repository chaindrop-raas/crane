// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernanceTokenFactory.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    function deployGovernanceTokenFactory() public {
        OrigamiGovernanceTokenFactory factoryImpl;
        TransparentUpgradeableProxy factoryProxy;
        OrigamiGovernanceTokenFactory factory;
        ProxyAdmin factoryAdmin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiGovernanceTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiGovernanceTokenFactory(address(factoryProxy));
        factory.initialize();

        vm.stopBroadcast();
    }

    function deployMembershipTokenFactory() public {
        OrigamiMembershipTokenFactory factoryImpl;
        TransparentUpgradeableProxy factoryProxy;
        OrigamiMembershipTokenFactory factory;
        ProxyAdmin factoryAdmin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
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

    function deployMembershipToken(address owner, string calldata name, string calldata symbol, string calldata baseURI)
        public
    {
        OrigamiMembershipToken impl;
        TransparentUpgradeableProxy proxy;
        OrigamiMembershipToken token;
        ProxyAdmin admin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
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

    function deployGovernanceToken(address owner, string calldata name, string calldata symbol, uint256 supplyCap)
        public
    {
        OrigamiGovernanceToken impl;
        TransparentUpgradeableProxy proxy;
        OrigamiGovernanceToken token;
        ProxyAdmin admin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        admin = new ProxyAdmin();
        impl = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );

        token = OrigamiGovernanceToken(address(proxy));
        token.initialize(owner, name, symbol, supplyCap);

        vm.stopBroadcast();
    }
}
