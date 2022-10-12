// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.17;

import "@std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/versions/OrigamiGovernanceTokenTestVersion.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/utils/Strings.sol";

abstract contract OGTAddressHelper {
    address public deployer = address(0x6);
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public mintee = address(0x3);
    address public pauser = address(0x4);
    address public transferrer = address(0x5);
}

abstract contract OGTHelper is OGTAddressHelper, Test {
    OrigamiGovernanceToken public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernanceToken public token;
    ProxyAdmin public admin;

    constructor() {
        vm.startPrank(deployer);
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
        vm.stopPrank();
    }
}

contract DeployGovernanceTokenTest is OGTAddressHelper, Test {
    OrigamiGovernanceToken public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernanceToken public token;
    ProxyAdmin public admin;

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
        vm.expectRevert("Admin address cannot be zero");
        token.initialize(
            address(0),
            "Deciduous Tree DAO Governance",
            "DTDG",
            10000000000000000000000000000
        );
    }
}

contract UpgradeGovernanceTokenTest is Test, OGTAddressHelper {
    OrigamiGovernanceToken public implV1;
    OrigamiGovernanceTokenTestVersion public implV2;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernanceToken public tokenV1;
    OrigamiGovernanceTokenTestVersion public tokenV2;
    ProxyAdmin public admin;

    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        admin = new ProxyAdmin();
        implV1 = new OrigamiGovernanceToken();
        proxy = new TransparentUpgradeableProxy(
            address(implV1),
            address(admin),
            ""
        );
        tokenV1 = OrigamiGovernanceToken(
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
        vm.expectRevert("Initializable: contract is already initialized");
        tokenV1.initialize(
            owner,
            "EVEN MOAR Deciduous Tree DAO Governance",
            "EMDTDG",
            10000000000000000000000000000
        );
    }

    function testCanUpgrade() public {
        implV2 = new OrigamiGovernanceTokenTestVersion();
        admin.upgrade(proxy, address(implV2));
        tokenV2 = OrigamiGovernanceTokenTestVersion(address(proxy));
        vm.prank(owner);

        vm.expectEmit(true, true, true, true, address(tokenV2));

        // TransferEnabled does not exist in tokenV1, so it being emited here is proof that the upgrade worked
        emit TransferEnabled(owner, true);

        tokenV2.enableTransfer();
    }
}

contract MintingGovernanceTokenTest is OGTHelper {
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

    function testMinting(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.mint(mintee, amount);
        assertEq(token.balanceOf(mintee), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintingRevertsWhenNotMinter() public {
        vm.stopPrank();
        vm.expectRevert(
            "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
        );
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenPaused() public {
        vm.stopPrank();
        vm.prank(owner);
        token.pause();
        vm.prank(minter);
        vm.expectRevert("Pausable: paused");
        token.mint(mintee, 100);
    }

    function testMintingRevertsWhenMintingMoreThanCap() public {
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 10000000000000000000000000001);
    }

    function testMintingRevertsWhenMintingMoreThanCapAfterMinting() public {
        token.mint(mintee, 10000000000000000000000000000);
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 1);
    }

    function testMintingRevertsWhenMintingToZeroAddress() public {
        vm.expectRevert("ERC20: mint to the zero address");
        token.mint(address(0), 100);
    }

    function testEmitsAnEventWhenMinting() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit GovernanceTokensMinted(minter, mintee, 100);
        token.mint(mintee, 100);
    }
}

contract CappedGovernanceTokenTest is OGTHelper {
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
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(mintee, 10000000000000000000000000001);
    }
}

contract BurnGovernanceTokenTest is OGTHelper {
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

    function testRevertsWhenNonAdminAttemptsToEnableBurn(address nonAdmin)
        public
    {
        vm.assume(nonAdmin != owner);
        vm.stopPrank();
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableBurn();
    }

    function testRevertsWhenNonAdminAttemptsToDisableBurn(address nonAdmin)
        public
    {
        vm.stopPrank();
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableBurn();
    }

    function testRevertsWhenCallingEnableBurnAndBurnIsAlreadyEnabled() public {
        token.enableBurn();
        vm.expectRevert("Burnable: burning is enabled");
        token.enableBurn();
    }

    function testRevertsWhenCallingDisableBurnAndBurnIsAlreadyDisabled()
        public
    {
        vm.expectRevert("Burnable: burning is disabled");
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
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(mintee, 10);
    }

    function testCanBurnAsHolderWhenBurnIsEnabled(uint96 amount) public {
        vm.assume(amount < token.cap());
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, amount);
        vm.prank(mintee);
        token.burn(amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCanBurnFromWalletWithAllowanceWhenEnabled(uint96 amount)
        public
    {
        vm.assume(amount < token.cap());
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, amount);
        vm.prank(mintee);
        token.approve(minter, amount);
        vm.prank(minter);
        token.burnFrom(mintee, amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCannotBurnMoreThanAllowanceWhenEnabled() public {
        token.enableBurn();
        vm.stopPrank();
        vm.prank(minter);
        token.mint(mintee, 100);
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(minter);
        token.burnFrom(mintee, 11);
    }
}

contract PauseGovernanceTokenTest is OGTHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
    }

    function testCannotPauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != deployer);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != owner);

        vm.stopPrank();
        vm.prank(nonPauser);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPauser),
                " is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.pause();
    }

    function testCannotUnpauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != deployer);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != owner);

        token.pause();
        vm.stopPrank();
        vm.prank(nonPauser);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonPauser),
                " is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.unpause();
    }

    function testCanMintWhenUnpaused(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        assertEq(token.balanceOf(mintee), amount);
    }

    function testCannotMintWhenPaused() public {
        token.pause();
        vm.expectRevert("Pausable: paused");
        token.mint(mintee, 100);
    }

    function testCanBurnWhenUnpausedAndBurnable(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        token.enableBurn();
        vm.stopPrank();
        vm.prank(mintee);
        token.burn(amount);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testCannotBurnWhenPaused() public {
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.burn(100);
    }

    function testCanTransferWhenUnpausedAndTransferrable(uint96 amount) public {
        vm.assume(amount < token.cap());
        assertFalse(token.paused());
        token.mint(mintee, amount);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(mintee);
        token.transfer(minter, amount);
        assertEq(token.balanceOf(minter), amount);
    }

    function testCannotTransferWhenPausedAndTransferEnabled(uint96 amount)
        public
    {
        vm.assume(amount < token.cap());
        token.mint(mintee, amount);
        token.enableTransfer();
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.transfer(minter, amount);
    }

    function testTransferrerRoleCannotTransferWhenPaused() public {
        token.grantRole(token.TRANSFERRER_ROLE(), mintee);
        token.mint(mintee, 100);
        token.pause();
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        vm.prank(mintee);
        token.transfer(minter, 100);
    }
}

contract TransferGovernanceTokenTest is OGTHelper {
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

    function testCanOnlyEnableTransferAsAdmin(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.stopPrank();
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableTransfer();
        vm.prank(owner);
        token.enableTransfer();
        assertTrue(token.transferrable());
    }

    function testCanOnlyDisableTransferAsAdmin(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(nonAdmin),
                " is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableTransfer();
        vm.prank(owner);
        token.disableTransfer();
        assertFalse(token.transferrable());
    }

    function testCannotEnableTransferWhenAlreadyEnabled() public {
        token.enableTransfer();
        vm.expectRevert("Transferrable: transfers are enabled");
        token.enableTransfer();
    }

    function testCannotDisableTransferWhenAlreadyDisabled() public {
        vm.expectRevert("Transferrable: transfers are disabled");
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
        vm.expectRevert("Transferrable: transfers are disabled");
        token.transfer(minter, 10);
        vm.expectRevert("Transferrable: transfers are disabled");
        token.transferFrom(mintee, minter, 10);
    }

    function testCanTransferWhenTransfersAreEnabled() public {
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();
        vm.prank(mintee);
        token.transfer(minter, 10);
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
