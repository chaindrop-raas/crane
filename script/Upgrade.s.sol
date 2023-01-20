// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiMembershipToken.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

contract UpgradeScript is Script {
    function upgradeGovernanceToken(address proxyAdmin, address payable transparentProxy) public {
        OrigamiGovernanceToken newImpl;
        TransparentUpgradeableProxy proxy;
        ProxyAdmin admin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        newImpl = new OrigamiGovernanceToken();
        admin = ProxyAdmin(proxyAdmin);
        proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(newImpl));

        vm.stopBroadcast();
    }

    function upgradeMembershipToken(address proxyAdmin, address payable transparentProxy) public {
        OrigamiMembershipToken newImpl;
        TransparentUpgradeableProxy proxy;
        ProxyAdmin admin;

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        newImpl = new OrigamiMembershipToken();
        admin = ProxyAdmin(proxyAdmin);
        proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(newImpl));

        vm.stopBroadcast();
    }
}
