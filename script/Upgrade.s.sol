// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiMembershipToken.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

contract UpgradeScript is Script {
    /**
     * @dev deploys a new governance token implementation and upgrades the proxy to it - use for first upgrade to a new implementation
     * @param proxyAdmin address of the proxy admin
     * @param transparentProxy address of the transparent proxy
     */
    function deployAndUpgradeGovernanceToken(address proxyAdmin, address payable transparentProxy) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OrigamiGovernanceToken impl = new OrigamiGovernanceToken();
        ProxyAdmin admin = ProxyAdmin(proxyAdmin);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(impl));

        vm.stopBroadcast();
    }

    /**
     * @dev upgrades the proxy to the specified implementation - use with previously deployed implementation
     * @param proxyAdmin address of the proxy admin
     * @param transparentProxy address of the transparent proxy
     * @param implementation address of the implementation
     */
    function upgradeGovernanceToken(address proxyAdmin, address payable transparentProxy, address implementation)
        public
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OrigamiGovernanceToken impl = OrigamiGovernanceToken(implementation);
        ProxyAdmin admin = ProxyAdmin(proxyAdmin);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(impl));

        vm.stopBroadcast();
    }

    /**
     * @dev deploys a new membership token implementation and upgrades the proxy to it - use for first upgrade to a new implementation
     * @param proxyAdmin address of the proxy admin
     * @param transparentProxy address of the transparent proxy
     */
    function deployAndUpgradeMembershipToken(address payable transparentProxy, address proxyAdmin) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OrigamiMembershipToken impl = new OrigamiMembershipToken();
        ProxyAdmin admin = ProxyAdmin(proxyAdmin);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(impl));

        vm.stopBroadcast();
    }

    /**
     * @dev upgrades the proxy to the specified implementation - use with previously deployed implementation
     * @param proxyAdmin address of the proxy admin
     * @param transparentProxy address of the transparent proxy
     * @param implementation address of the implementation
     */
    function upgradeMembershipToken(address payable transparentProxy, address proxyAdmin, address implementation)
        public
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OrigamiMembershipToken impl = OrigamiMembershipToken(implementation);
        ProxyAdmin admin = ProxyAdmin(proxyAdmin);
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(transparentProxy);
        admin.upgrade(proxy, address(impl));

        vm.stopBroadcast();
    }
}
