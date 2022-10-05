// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "@std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/versions/OrigamiGovernanceTokenBeforeInitialAuditFeedback.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract AddressHelper {
    address owner = address(0x1);
    address minter = address(0x2);
    address mintee = address(0x3);
    address pauser = address(0x4);
    address transferrer = address(0x5);
}

abstract contract OGTHelper is AddressHelper {
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

contract MintingGovernanceTokenTest is OGTHelper, Test {
    event GovernanceTokensMinted(
        address indexed caller,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
    }

    function testMinting() public {
        token.mint(mintee, 100);
        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.totalSupply(), 100);
    }

    function testMintingRevertsWhenNotMinter() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
            )
        );
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenPaused() public {
        vm.stopPrank();
        vm.prank(owner);
        token.pause();
        vm.expectRevert(bytes("Pausable: paused"));
        vm.prank(minter);
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenMintingMoreThanCap() public {
        vm.expectRevert(bytes("ERC20Capped: cap exceeded"));
        token.mint(mintee, 10000000000000000000000000001);
    }

    function testMintingRevertsWhenMintingMoreThanCapAfterMinting() public {
        token.mint(mintee, 10000000000000000000000000000);
        vm.expectRevert(bytes("ERC20Capped: cap exceeded"));
        token.mint(mintee, 1);
    }

    function testMintingRevertsWhenMintingToZeroAddress() public {
        vm.expectRevert(bytes("ERC20: mint to the zero address"));
        token.mint(address(0), 100);
    }

    function testEmitsAnEventWhenMinting() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit GovernanceTokensMinted(minter, mintee, 100);
        token.mint(mintee, 100);
    }
}

contract CappedGovernanceTokenTest is OGTHelper, Test {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
    }

    function testCanMintUpToCappedSupply() public {
        token.mint(mintee, 10000000000000000000000000000);
        assertEq(token.balanceOf(mintee), 10000000000000000000000000000);
    }

    function testCannotMintMoreThanCappedSupply() public {
        vm.expectRevert(bytes("ERC20Capped: cap exceeded"));
        token.mint(mintee, 10000000000000000000000000001);
    }
}

contract BurnGovernanceTokenTest is OGTHelper, Test {
    event BurnEnabled(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
    }

    function testCanEnableBurnAsAdmin() public {
        token.enableBurn();
        assertTrue(token.burnable());
    }

    function testCanDisableBurnAsAdmin() public {
        token.enableBurn();
        token.disableBurn();
        assertFalse(token.burnable());
    }

    function testRevertsWhenNonAdminAttemptsToEnableBurn() public {
        vm.stopPrank();
        vm.startPrank(minter);
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableBurn();
    }

    function testRevertsWhenNonAdminAttemptsToDisableBurn() public {
        vm.stopPrank();
        vm.startPrank(minter);
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableBurn();
    }

    function testRevertsWhenCallingEnableBurnAndBurnIsAlreadyEnabled() public {
        token.enableBurn();
        vm.expectRevert(bytes("Burnable: burning is enabled"));
        token.enableBurn();
    }

    function testRevertsWhenCallingDisableBurnAndBurnIsAlreadyDisabled()
        public
    {
        vm.expectRevert(bytes("Burnable: burning is disabled"));
        token.disableBurn();
    }

    function testEmitsBurnEnabledWhenEnabled() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit BurnEnabled(owner, true);
        token.enableBurn();
    }

    function testEmitsBurnEnabledWhenDisabled() public {
        token.enableBurn();
        vm.expectEmit(true, true, true, true, address(token));
        emit BurnEnabled(owner, false);
        token.disableBurn();
    }

    function testCannotBurnAsNonHolder() public {
        vm.stopPrank();
        vm.startPrank(minter);
        token.mint(mintee, 100);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        token.burnFrom(mintee, 10);
    }

    function testCanBurnAsHolderWhenBurnIsEnabled() public {
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        vm.prank(mintee);
        token.burn(10);
        assertEq(token.balanceOf(mintee), 90);
    }

    function testCanBurnFromWalletWithAllowanceWhenEnabled() public {
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.prank(minter);
        token.burnFrom(mintee, 10);
        assertEq(token.balanceOf(mintee), 90);
    }

    function testCannotBurnMoreThanAllowanceWhenEnabled() public {
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        vm.prank(minter);
        token.burnFrom(mintee, 11);
    }
}

contract PauseGovernanceTokenTest is OGTHelper, Test {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
    }

    function testCannotPauseAsNonPauser() public {
        vm.stopPrank();
        vm.prank(minter);
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.pause();
    }

    function testCannotUnpauseAsNonPauser() public {
        token.pause();
        vm.stopPrank();
        vm.prank(minter);
        vm.expectRevert(
            bytes(
                "AccessControl: account 0x0000000000000000000000000000000000000002 is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.unpause();
    }

    function testCanMintWhenUnpaused() public {
        assertFalse(token.paused());
        token.mint(mintee, 100);
        assertEq(token.balanceOf(mintee), 100);
    }

    function testCannotMintWhenPaused() public {
        token.pause();
        vm.expectRevert(bytes("Pausable: paused"));
        token.mint(mintee, 100);
    }

    function testCanBurnWhenUnpausedAndBurnable() public {
        assertFalse(token.paused());
        token.mint(mintee, 100);
        token.enableBurn();
        vm.stopPrank();
        vm.prank(mintee);
        token.burn(10);
        assertEq(token.balanceOf(mintee), 90);
    }

    function testCannotBurnWhenPaused() public {
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert(bytes("Pausable: paused"));
        vm.prank(mintee);
        token.burn(100);
    }

    function testCanTransferWhenUnpausedAndTransferrable() public {
        assertFalse(token.paused());
        token.mint(mintee, 100);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(mintee);
        token.transfer(minter, 10);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCannotTransferWhenPausedAndTransferEnabled() public {
        token.mint(mintee, 100);
        token.enableTransfer();
        token.pause();
        vm.stopPrank();
        vm.expectRevert(bytes("Pausable: paused"));
        vm.prank(mintee);
        token.transfer(minter, 100);
    }

    function testTransferrerRoleCannotTransferWhenPaused() public {
        token.grantRole(token.TRANSFERRER_ROLE(), mintee);
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert(bytes("Pausable: paused"));
        vm.prank(mintee);
        token.transfer(minter, 100);
    }
}

contract TransferGovernanceTokenTest is OGTHelper, Test {
    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.TRANSFERRER_ROLE(), transferrer);
    }

    function testEmitsTransferEnabledEventWhenEnabled() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, true);
        token.enableTransfer();
    }

    function testEmitsTransferEnabledEventWhenDisabled() public {
        token.enableTransfer();
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, false);
        token.disableTransfer();
    }

    function testCanOnlyEnableTransferAsAdmin() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableTransfer();
        vm.prank(owner);
        token.enableTransfer();
        assertTrue(token.transferrable());
    }

    function testCanOnlyDisableTransferAsAdmin() public {
        token.enableTransfer();
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableTransfer();
        vm.prank(owner);
        token.disableTransfer();
        assertFalse(token.transferrable());
    }

    function testCannotEnableTransferWhenAlreadyEnabled() public {
      token.enableTransfer();
      vm.expectRevert(bytes("Transferrable: transfers are enabled"));
      token.enableTransfer();
    }

    function testCannotDisableTransferWhenAlreadyDisabled() public {
      vm.expectRevert(bytes("Transferrable: transfers are disabled"));
      token.disableTransfer();
    }

    function testCanMintWhenTransferIsDisabled() public {
      assertFalse(token.transferrable());
      token.mint(mintee, 100);
      assertEq(token.balanceOf(mintee), 100);
    }

    function testCannotTransferWhenTransferDisabled() public {
      token.enableBurn();
      assertFalse(token.transferrable());
      token.mint(mintee, 100);
      vm.stopPrank();
      vm.startPrank(mintee);
      vm.expectRevert(bytes("Transferrable: transfers are disabled"));
      token.transfer(minter, 10);
      vm.expectRevert(bytes("Transferrable: transfers are disabled"));
      token.transferFrom(mintee, minter, 10);
    }

    function testCanTransferWhenTransfersAreEnabled() public {
      token.enableTransfer();
      token.mint(mintee, 100);
      vm.stopPrank();
      vm.prank(mintee);
      token.transfer(minter,10);
      assertEq(token.balanceOf(minter), 10);
      vm.prank(minter);
      token.transfer(mintee, 1);
      assertEq(token.balanceOf(minter), 9);
      assertEq(token.balanceOf(mintee), 91);
    }

    function testCanTransferAsTransferrerWhenTransfersAreDisabled() public {
      assertFalse(token.transferrable());
      token.mint(transferrer, 100);
      vm.stopPrank();
      vm.prank(transferrer);
      token.transfer(mintee, 10);
      assertEq(token.balanceOf(mintee), 10);
    }

    function testCanTransferAsTransferrerWhenTransfersAreEnabled() public {
      token.enableTransfer();
      token.mint(transferrer, 100);
      vm.stopPrank();
      vm.prank(transferrer);
      token.transfer(mintee, 10);
      assertEq(token.balanceOf(mintee), 10);
    }

}
