// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract AddressHelper {
    address owner = address(0x1);
    address minter = address(0x2);
    address mintee = address(0x3);
    address recipient = address(0x4);
    address revoker = address(0x5);
    address pauser = address(0x6);
}

abstract contract OMTHelper is AddressHelper {
    OrigamiGovernanceToken impl;
    TransparentUpgradeableProxy proxy;
    OrigamiGovernanceToken token;
    ProxyAdmin admin;

    constructor() {
        admin = new ProxyAdmin();
        impl = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        token = OrigamiGovernanceToken(address(proxy));
        token.initialize(
            owner,
            "Deciduous Tree DAO Governance",
            "DTDG",
            10000000000000000000000000000
        );
    }
}

contract DeployGovernanceTokenTest is AddressHelper, Test {
    OrigamiGovernanceToken impl;
    TransparentUpgradeableProxy proxy;
    OrigamiGovernanceToken token;
    ProxyAdmin admin;

    function setUp() public {
        admin = new ProxyAdmin();
        impl = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
    }

    function testDeploy() public {
        token = OrigamiGovernanceToken(address(proxy));
        token.initialize(
            owner,
            "Deciduous Tree DAO Governance",
            "DTDG",
            10000000000000000000000000000
        );
        assertEq(token.name(), "Deciduous Tree DAO Governance");
        assertEq(token.symbol(), "DTDG");
        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), 10000000000000000000000000000);
    }

    function testDeployRevertsWhenAdminIsAdressZero() public {
        token = OrigamiGovernanceToken(address(proxy));
        vm.expectRevert(bytes("Admin address cannot be zero"));
        token.initialize(
            address(0),
            "Deciduous Tree DAO Governance",
            "DTDG",
            10000000000000000000000000000
        );
    }
}
