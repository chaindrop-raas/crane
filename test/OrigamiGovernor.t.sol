// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.17;

import "@std/Test.sol";
import "src/OrigamiGovernor.sol";
import "src/OrigamiTimelock.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract GovAddressHelper {
    address public deployer = address(0x1);
    address public proxyAdmin = address(0x2);
}

abstract contract GovHelper is GovAddressHelper, Test {
    OrigamiTimelock public timelockImpl;
    TransparentUpgradeableProxy public timelockProxy;
    OrigamiTimelock public timelock;
    ProxyAdmin public timelockAdmin;

    OrigamiGovernor public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernor public governor;
    ProxyAdmin public admin;

    constructor() {
        vm.startPrank(proxyAdmin);

        timelockAdmin = new ProxyAdmin();
        timelockImpl = new OrigamiTimelock();
        timelockProxy = new TransparentUpgradeableProxy(
            address(timelockImpl),
            address(timelockAdmin),
            ""
        );
        timelock = OrigamiTimelock(payable(timelockProxy));
        timelock.initialize(0, new address[](0), new address[](0));


        admin = new ProxyAdmin();
        impl = new OrigamiGovernor();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        governor = OrigamiGovernor(payable(proxy));
        vm.stopPrank();
        governor.initialize(timelock, 91984, 91984, 0);
    }
}

contract OrigamiGovernorTest is GovHelper {
    function testInformationalFunctions() public {
        assertEq(address(governor.timelock()), address(timelock));
        assertEq(governor.name(), "OrigamiGovernor");
        assertEq(governor.votingDelay(), 91984);
        assertEq(governor.votingPeriod(), 91984);
        assertEq(governor.proposalThreshold(), 0);
        assertEq(governor.quorumNumerator(), 10);
    }
}
