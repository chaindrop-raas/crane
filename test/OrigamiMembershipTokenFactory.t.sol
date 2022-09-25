// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiMembershipTokenFactory.sol";
import "src/versions/OrigamiMembershipTokenFactoryTestVersion.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract AddressHelper {
    address admin = address(0x1);
    address owner = address(0x2);
    address rando = address(0x3);
}

abstract contract OMTFHelper is AddressHelper, Test {
    OrigamiMembershipTokenFactory factoryImpl;
    TransparentUpgradeableProxy factoryProxy;
    OrigamiMembershipTokenFactory factory;
    ProxyAdmin factoryAdmin;
    OrigamiMembershipToken token;

    function setUp() public {
        vm.startPrank(admin);
        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiMembershipTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiMembershipTokenFactory(address(factoryProxy));
        factory.initialize();

        address tokenProxyAddress = factory.createOrigamiMembershipToken(
            owner,
            "Factory Membership Token",
            "FMT",
            "ipfs://deadbeef/"
        );
        token = OrigamiMembershipToken(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
    }
}

contract DeployingMembershipTokenFactoryTest is AddressHelper, Test {
    OrigamiMembershipTokenFactory factoryImpl;
    TransparentUpgradeableProxy factoryProxy;
    OrigamiMembershipTokenFactory factory;
    ProxyAdmin factoryAdmin;
    OrigamiMembershipToken token;

    event OrigamiMembershipTokenCreated(
        address indexed caller,
        address indexed proxy
    );

    function setUp() public {
        vm.startPrank(admin);

        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiMembershipTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiMembershipTokenFactory(address(factoryProxy));
        factory.initialize();
    }

    function testCreateEmitsEvent() public {
        // we skip validating argument 2 because the address is not known until after the create call
        vm.expectEmit(true, false, true, true, address(factory));

        emit OrigamiMembershipTokenCreated(admin, address(0x0));

        address tokenProxyAddress = factory.createOrigamiMembershipToken(
            owner,
            "Factory Membership Token",
            "FMT",
            "ipfs://deadbeef/"
        );
        token = OrigamiMembershipToken(tokenProxyAddress);
        vm.stopPrank();
        vm.prank(owner);
        assertEq(token.name(), "Factory Membership Token");
        assertEq(token.symbol(), "FMT");
    }
}

contract AccessControlForMembershipTokenFactoryTest is OMTFHelper {
    function testOnlyAdminCanCreate() public {
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        factory.createOrigamiMembershipToken(
            owner,
            "Factory Membership Token",
            "FMT",
            "ipfs://deadbeef/"
        );
    }

    function testCanGrantRoleOnFactoryIfAdmin() public {
        vm.stopPrank();
        vm.startPrank(admin);
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), rando);
        assertEq(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), rando), true);
    }

    function testCanGrantRoleOnInstanceIfOwner() public {
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), rando);
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), rando), true);
    }
}

contract MembershipTokenFactoryProxyAddressTest is OMTFHelper {
    function testProxyAddressIsCorrect() public {
        assertEq(address(token), address(factory.getProxyContractAddress(0)));
    }

    function testCannotGetProxyAddressOutOfIndex() public {
        vm.expectRevert(bytes("Proxy address index out of bounds"));
        factory.getProxyContractAddress(1);
    }
}

contract UpgradingMembershipTokenFactoryTest is OMTFHelper {
    OrigamiMembershipTokenFactoryTestVersion newFactoryImpl;
    OrigamiMembershipTokenFactoryTestVersion newFactory;
    OrigamiMembershipTokenTestVersion newTokenImpl;
    OrigamiMembershipTokenTestVersion newToken;

    function testCanUpgradeFactory() public {
        vm.stopPrank();
        vm.startPrank(admin);
        newFactoryImpl = new OrigamiMembershipTokenFactoryTestVersion();
        factoryAdmin.upgrade(factoryProxy, address(newFactoryImpl));
        newFactory = OrigamiMembershipTokenFactoryTestVersion(
            address(factoryProxy)
        );

        // call a function that only exists in the new version
        assertEq(newFactory.isFromUpgrade(), true);

        // separately set the new token implementation
        newTokenImpl = new OrigamiMembershipTokenTestVersion();
        newFactory.setTokenImplementation(address(newTokenImpl));

        // create a new token and verify that it is also upgraded
        address tokenProxyAddress = newFactory.createOrigamiMembershipToken(
            owner,
            "Upgraded Factory Membership Token",
            "UFMT",
            "ipfs://deadfee7/"
        );
        newToken = OrigamiMembershipTokenTestVersion(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
        assertEq(newToken.name(), "Upgraded Factory Membership Token");
        assertEq(newToken.isFromUpgrade(), true);
        // NB: previously deployed tokens are not upgraded, forge doesn't
        // provide a way to assert a selector/member is invalid, it registers as
        // a compiler error, so you can uncomment this to see that it fails:
        // token.isFromUpgrade();
    }
}

contract UpgradingOnlyTheMembershipTokenImplementationTest is OMTFHelper {
    OrigamiMembershipTokenTestVersion newTokenImpl;
    OrigamiMembershipTokenTestVersion newToken;

    function testUpgradingTokenImplementationProducesUpdatedToken() public {
        vm.stopPrank();
        vm.startPrank(admin);
        newTokenImpl = new OrigamiMembershipTokenTestVersion();
        factory.setTokenImplementation(address(newTokenImpl));
        address tokenProxyAddress = factory.createOrigamiMembershipToken(
            owner,
            "Upgraded Factory Membership Token",
            "UFMT",
            "ipfs://deadfee7/"
        );
        newToken = OrigamiMembershipTokenTestVersion(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
        assertEq(newToken.isFromUpgrade(), true);
    }

    function testCannotCallSetTokenImplementationAsNonAdmin() public {
        newTokenImpl = new OrigamiMembershipTokenTestVersion();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        factory.setTokenImplementation(address(newTokenImpl));
    }
}