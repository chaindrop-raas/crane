// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernanceTokenFactory.sol";
import "src/versions/OrigamiGovernanceTokenFactoryTestVersion.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract AddressHelper {
    address admin = address(0x1);
    address owner = address(0x2);
    address rando = address(0x3);
}

abstract contract OMTFHelper is AddressHelper, Test {
    OrigamiGovernanceTokenFactory factoryImpl;
    TransparentUpgradeableProxy factoryProxy;
    OrigamiGovernanceTokenFactory factory;
    ProxyAdmin factoryAdmin;
    OrigamiGovernanceToken token;

    function setUp() public {
        vm.startPrank(admin);
        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiGovernanceTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiGovernanceTokenFactory(address(factoryProxy));
        factory.initialize();

        address tokenProxyAddress = factory.createOrigamiGovernanceToken(
            owner,
            "Factory Governance Token",
            "FGT",
            10000000000000000000000000000
        );
        token = OrigamiGovernanceToken(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
    }
}

contract DeployingGovernanceTokenFactoryTest is AddressHelper, Test {
    OrigamiGovernanceTokenFactory factoryImpl;
    TransparentUpgradeableProxy factoryProxy;
    OrigamiGovernanceTokenFactory factory;
    ProxyAdmin factoryAdmin;
    OrigamiGovernanceToken token;

    event OrigamiGovernanceTokenCreated(
        address indexed caller,
        address indexed proxy
    );

    function setUp() public {
        vm.startPrank(admin);

        factoryAdmin = new ProxyAdmin();
        factoryImpl = new OrigamiGovernanceTokenFactory();
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            address(factoryAdmin),
            ""
        );
        factory = OrigamiGovernanceTokenFactory(address(factoryProxy));
        factory.initialize();
    }

    function testCreateEmitsEvent() public {
        // we skip validating argument 2 because the address is not known until after the create call
        vm.expectEmit(true, false, true, true, address(factory));

        emit OrigamiGovernanceTokenCreated(admin, address(0x0));

        address tokenProxyAddress = factory.createOrigamiGovernanceToken(
            owner,
            "Factory Governance Token",
            "FGT",
            10000000000000000000000000000
        );
        token = OrigamiGovernanceToken(tokenProxyAddress);
        vm.stopPrank();
        assertEq(token.name(), "Factory Governance Token");
        assertEq(token.symbol(), "FGT");
    }
}

contract AccessControlForGovernanceTokenFactoryTest is OMTFHelper {
    function testOnlyAdminCanCreate() public {
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        factory.createOrigamiGovernanceToken(
            owner,
            "Factory Governance Token",
            "FGT",
            10000000000000000000000000000
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

contract GovernanceTokenFactoryProxyAddressTest is OMTFHelper {
    function testProxyAddressIsCorrect() public {
        assertEq(address(token), address(factory.getProxyContractAddress(0)));
    }

    function testCannotGetProxyAddressOutOfIndex() public {
        vm.expectRevert(bytes("Proxy address index out of bounds"));
        factory.getProxyContractAddress(1);
    }
}

contract UpgradingGovernanceTokenFactoryTest is OMTFHelper {
    OrigamiGovernanceTokenFactoryTestVersion newFactoryImpl;
    OrigamiGovernanceTokenFactoryTestVersion newFactory;
    OrigamiGovernanceTokenTestVersion newTokenImpl;
    OrigamiGovernanceTokenTestVersion newToken;

    function testCanUpgradeFactory() public {
        vm.stopPrank();
        vm.startPrank(admin);
        newFactoryImpl = new OrigamiGovernanceTokenFactoryTestVersion();
        factoryAdmin.upgrade(factoryProxy, address(newFactoryImpl));
        newFactory = OrigamiGovernanceTokenFactoryTestVersion(
            address(factoryProxy)
        );

        // call a function that only exists in the new version
        assertEq(newFactory.isFromUpgrade(), true);

        // separately set the new token implementation
        newTokenImpl = new OrigamiGovernanceTokenTestVersion();
        newFactory.setTokenImplementation(address(newTokenImpl));

        // create a new token and verify that it is also upgraded
        address tokenProxyAddress = newFactory.createOrigamiGovernanceToken(
            owner,
            "Upgraded Factory Governance Token",
            "UFGT",
            10000000000000000000000000000
        );
        newToken = OrigamiGovernanceTokenTestVersion(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
        assertEq(newToken.name(), "Upgraded Factory Governance Token");
        assertEq(newToken.isFromUpgrade(), true);
        // NB: previously deployed tokens are not upgraded, forge doesn't
        // provide a way to assert a selector/member is invalid, it registers as
        // a compiler error, so you can uncomment this to see that it fails:
        // token.isFromUpgrade();
    }
}

contract UpgradingOnlyTheGovernanceTokenImplementationTest is OMTFHelper {
    OrigamiGovernanceTokenTestVersion newTokenImpl;
    OrigamiGovernanceTokenTestVersion newToken;

    function testUpgradingTokenImplementationProducesUpdatedToken() public {
        vm.stopPrank();
        vm.startPrank(admin);
        newTokenImpl = new OrigamiGovernanceTokenTestVersion();
        factory.setTokenImplementation(address(newTokenImpl));
        address tokenProxyAddress = factory.createOrigamiGovernanceToken(
            owner,
            "Upgraded Factory Governance Token",
            "UFGT",
            10000000000000000000000000000
        );
        newToken = OrigamiGovernanceTokenTestVersion(tokenProxyAddress);
        vm.stopPrank();
        vm.startPrank(owner);
        assertEq(newToken.isFromUpgrade(), true);
    }

    function testCannotCallSetTokenImplementationAsNonAdmin() public {
        newTokenImpl = new OrigamiGovernanceTokenTestVersion();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        factory.setTokenImplementation(address(newTokenImpl));
    }
}
