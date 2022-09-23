// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/versions/OrigamiGovernanceTokenBeforeInitialAuditFeedback.sol";
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

contract UpgradeGovernanceTokenTest is Test, AddressHelper {
    OrigamiGovernanceTokenBeforeInitialAuditFeedback implV1;
    OrigamiGovernanceToken implV2;
    TransparentUpgradeableProxy proxy;
    OrigamiGovernanceTokenBeforeInitialAuditFeedback tokenV1;
    OrigamiGovernanceToken tokenV2;
    ProxyAdmin admin;

    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        admin = new ProxyAdmin();
        implV1 = new OrigamiGovernanceTokenBeforeInitialAuditFeedback();
        proxy = new TransparentUpgradeableProxy(
            address(implV1),
            address(admin),
            ""
        );
        tokenV1 = OrigamiGovernanceTokenBeforeInitialAuditFeedback(
            address(proxy)
        );

        tokenV1.initialize(
            owner,
            "Deciduous Tree DAO Governance",
            "DTDG",
            10000000000000000000000000000
        );
    }

    function testCanInitialize() public {
        assertEq(tokenV1.name(), "Deciduous Tree DAO Governance");
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        tokenV1.initialize(
            owner,
            "EVEN MOAR Deciduous Tree DAO Governance",
            "EMDTDG",
            10000000000000000000000000000
        );
    }

    function testCanUpgrade() public {
        implV2 = new OrigamiGovernanceToken();
        admin.upgrade(proxy, address(implV2));
        tokenV2 = OrigamiGovernanceToken(address(proxy));
        vm.prank(owner);

        vm.expectEmit(true, true, true, true, address(tokenV2));

        // TransferEnabled does not exist in tokenV1, so it being emited here is proof that the upgrade worked
        emit TransferEnabled(owner, true);

        tokenV2.enableTransfer();
    }
}
