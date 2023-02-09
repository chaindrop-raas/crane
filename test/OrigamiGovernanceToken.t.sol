// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "@std/Test.sol";
import "src/OrigamiGovernanceToken.sol";
import "test/versions/OrigamiGovernanceTokenTestVersion.sol";
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
    address public signer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
}

abstract contract OGTHelper is OGTAddressHelper, Test {
    OrigamiGovernanceToken public impl;
    ProxyAdmin public proxyAdmin;
    OrigamiGovernanceToken public token;

    constructor() {
        vm.startPrank(deployer);
        impl = new OrigamiGovernanceToken();
        proxyAdmin = new ProxyAdmin();
        token = deployNewToken(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
        vm.stopPrank();
    }

    function deployNewToken(address _owner, string memory _name, string memory _symbol, uint256 _cap)
        public
        returns (OrigamiGovernanceToken _token)
    {
        TransparentUpgradeableProxy proxy;
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        _token = OrigamiGovernanceToken(address(proxy));
        _token.initialize(_owner, _name, _symbol, _cap);
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
        token.initialize(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
        assertEq(token.name(), "Deciduous Tree DAO Governance");
        assertEq(token.symbol(), "DTDG");
        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), 10000000000000000000000000000);
    }

    function testDeployRevertsWhenAdminIsAdressZero() public {
        token = OrigamiGovernanceToken(address(proxy));
        vm.expectRevert("Admin address cannot be zero");
        token.initialize(address(0), "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
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
        tokenV1 = OrigamiGovernanceToken(address(proxy));

        tokenV1.initialize(owner, "Deciduous Tree DAO Governance", "DTDG", 10000000000000000000000000000);
    }

    function testCanInitialize() public {
        assertEq(tokenV1.name(), "Deciduous Tree DAO Governance");
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        tokenV1.initialize(owner, "EVEN MOAR Deciduous Tree DAO Governance", "EMDTDG", 10000000000000000000000000000);
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
    event Transfer(address indexed from, address indexed to, uint256 amount);

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
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
            )
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
        emit Transfer(address(0), mintee, 100);
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

    function testRevertsWhenNonAdminAttemptsToEnableBurn(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
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

    function testRevertsWhenNonAdminAttemptsToDisableBurn(address nonAdmin) public {
        vm.assume(nonAdmin != owner);
        vm.assume(nonAdmin != address(proxyAdmin));
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

    function testRevertsWhenCallingDisableBurnAndBurnIsAlreadyDisabled() public {
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

    function testCanBurnFromWalletWithAllowanceWhenEnabled(uint96 amount) public {
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
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
    }

    function testCanPauseAsPauser() public {
        vm.stopPrank();
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true, address(token));
        emit Paused(pauser);
        token.pause();
        assertTrue(token.paused());
    }

    function testCannotPauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != owner);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != address(proxyAdmin));

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

    function testCanUnpauseAsPauser() public {
        vm.stopPrank();
        vm.prank(pauser);
        token.pause();
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true, address(token));
        emit Unpaused(pauser);
        token.unpause();
        assertFalse(token.paused());
    }

    function testCannotUnpauseAsNonPauser(address nonPauser) public {
        vm.assume(nonPauser != owner);
        vm.assume(nonPauser != pauser);
        vm.assume(nonPauser != address(proxyAdmin));

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

    function testCannotTransferWhenPausedAndTransferEnabled(uint96 amount) public {
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
        vm.assume(nonAdmin != address(proxyAdmin));
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
        vm.assume(nonAdmin != address(proxyAdmin));
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
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.prank(minter);
        token.transferFrom(mintee, minter, 10);
        assertEq(token.balanceOf(minter), 19);
        assertEq(token.balanceOf(mintee), 81);
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

contract GovernanceTokenVotingPowerTest is OGTHelper {
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.TRANSFERRER_ROLE(), transferrer);

        // mint some tokens as owner
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();

        // warp to a new timestamp
        vm.warp(42);

        // delegate to self
        vm.prank(mintee);
        token.delegate(mintee);

        // warp to a new timestamp
        vm.warp(43);
    }

    function testDelegateEmitsDelegateChanged() public {
        address other = address(0x7);
        vm.prank(mintee);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(mintee, mintee, other);
        token.delegate(other);
    }

    function testDelegateEmitsDelegateVotesChanged() public {
        address other = address(0x7);
        address mintee2 = address(0x8);

        vm.prank(other);
        token.delegate(other);

        vm.prank(mintee);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 0, 100);
        token.delegate(other);

        // mint some more tokens to mintee
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 100, 200);
        token.mint(mintee, 100);

        // transfers from the delegator to the delegatee do not trigger a DelegateVotesChanged event, since the balance delegated would not change.
        // vm.prank(mintee);
        // vm.expectEmit(true, true, true, true, address(token));
        // emit DelegateVotesChanged(other, 200, 200);
        // token.transfer(other, 10);

        // mintee2 delegates to other
        vm.prank(mintee2);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(mintee2, address(0), other);
        token.delegate(other);

        // mintee2 gets more tokens
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateVotesChanged(other, 200, 210);
        token.mint(mintee2, 10);
    }

    function testGetVotesIsZeroBeforeDelegation() public {
        address other = address(0x7);

        vm.prank(owner);
        token.mint(other, 100);

        // check that other has no votes
        assertEq(token.getVotes(other), 0);

        // delegate and then check again
        vm.prank(other);
        token.delegate(other);
        assertEq(token.getVotes(other), 100);

        // mint and check updated balance
        vm.prank(owner);
        token.mint(other, 100);
        assertEq(token.getVotes(other), 200);
    }

    function testGetPastVotesSnapshotsAtTimestamp() public {
        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // visit the next block and make assertions
        vm.warp(44);
        assertEq(token.getPastVotes(mintee, 41), 0); // minting happened at timestamp 1 but delegation hasn't happened yet
        assertEq(token.getPastVotes(mintee, 42), 100); // delegation happened at timestamp 42
        assertEq(token.getPastVotes(mintee, 43), 200); // more minting happened at timestamp 43
    }

    function testGetPastTotalSupplySnapshotsAtTimestamp() public {
        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // visit the next block and make assertions
        vm.warp(44);
        assertEq(token.getPastTotalSupply(41), 100); // total supply is calc'd regardless of delegation
        assertEq(token.getPastTotalSupply(42), 100); // delegation happened at timestamp 42
        assertEq(token.getPastTotalSupply(43), 200); // more minting happened at timestamp 43
    }

    function testDelegatesReturnsDelegateOf(address delegatee) public {
        vm.prank(mintee);
        token.delegate(delegatee);
        assertEq(token.delegates(mintee), delegatee);
    }

    function testTransferVotingPower() public {
        address other = address(0x7);

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(other, 100);

        // self-delegate
        vm.prank(other);
        token.delegate(other);

        assertEq(token.getVotes(mintee), 100);
        assertEq(token.getVotes(other), 100);

        // transfer 10 tokens to mintee
        vm.prank(other);
        token.transfer(mintee, 10);

        // check that mintee has 110 votes
        assertEq(token.getVotes(mintee), 110);

        // check that other has 90 votes
        assertEq(token.getVotes(other), 90);
    }

    function testBurnAndMintPastSupplyAndPastVotesInteractions() public {
        vm.prank(owner);
        token.enableBurn();

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(mintee, 100);

        // burn some tokens
        vm.warp(44);
        vm.prank(mintee);
        token.burn(10);

        // check that mintee has 90 votes
        assertEq(token.getVotes(mintee), 190);

        // check that total supply is 190
        assertEq(token.totalSupply(), 190);

        // check that mintee has 100 votes at timestamp 42
        assertEq(token.getPastVotes(mintee, 42), 100);

        // check that total supply is 100 at timestamp 42
        assertEq(token.getPastTotalSupply(42), 100);

        // check that mintee has 200 votes at timestamp 43
        assertEq(token.getPastVotes(mintee, 43), 200);

        // check that total supply is 200 at timestamp 43
        assertEq(token.getPastTotalSupply(43), 200);

        // check that mintee has 190 votes at timestamp 44
        assertEq(token.getPastVotes(mintee, 44), 190);

        // check that total supply is 190 at timestamp 44
        assertEq(token.getPastTotalSupply(44), 190);
    }

    function testDelegateBySig() public {
        bytes32 r = 0x269626c92cabf71b49d866b0e09f35882d08a260bdb59a67fae51a1ceabc7757;
        bytes32 s = 0x0935d9b1ba980a1df5943b4cf597d72e1f6256cdaabe310251e55d5bbfdf51d6;
        uint8 v = 27;

        // delegate to self
        vm.expectEmit(true, true, true, true, address(token));
        emit DelegateChanged(signer, address(0), mintee);
        token.delegateBySig(mintee, 0, 242, v, r, s);
    }
}

contract GovernanceTokenTransferLockTest is OGTHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.enableTransfer();
        token.mint(mintee, 100);
        vm.stopPrank();
    }

    function testEmptyTransferLock() public {
        (uint256 amount, uint256 deadline) = token.getTransferLock(mintee);
        assertEq(amount, 0);
        assertEq(deadline, 0);
    }

    function testSetTransferLock() public {
        assertEq(block.timestamp, 1);
        vm.prank(mintee);
        token.setTransferLock(100, 1000);
        (uint256 amount, uint256 deadline) = token.getTransferLock(mintee);
        assertEq(amount, 100);
        assertEq(deadline, 1000);
    }

    function testCannotSetTransferLockAmountHigherThanBalance() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed balance");
        token.setTransferLock(101, 1000);
    }

    function testCannotTransferWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.setTransferLock(100, 1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your available balance while locked");
        token.transfer(minter, 10);
    }

    function testCanTransferSurplusWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.setTransferLock(90, 1704585600); // 2024-01-01
        vm.prank(mintee);
        token.transfer(minter, 10);
        assertEq(token.balanceOf(mintee), 90);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCanTransferAfterLockExpires() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.setTransferLock(100, 1704585600); // 2024-01-01

        // timelock date is inclusive, so an attempt to transfer at the exact timelock time will fail
        vm.warp(1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your available balance while locked");
        token.transfer(mintee, 10);

        // warp to the second immediately after the timelock expires and try again
        vm.prank(mintee);
        vm.warp(1704585601); // 2024-01-01
        token.transfer(minter, 10);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCannotUnderflowAmount() public {
        vm.prank(mintee);
        token.setTransferLock(100, 1000);
        // we would get an underflow revert if we weren't checking the balance
        // exceeds the amount, since we do, we get the built-in revert about the
        // amount being too high
        vm.prank(mintee);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(minter, 200);
    }
}

// This contract is stripped down as much as possible and intended to be used
// for snapshotting estimated gas costs for functions used by holders. Each test
// comes in a fuzzed and non-fuzzed version, providing multiple runs on a
// variety of inputs versus a baseline.  This is not an accurate measurement of
// gas costs, but can be a good way to ballpark gas consumption or to compare it
// with snapshots to see how changes might impact gas costs.
contract HolderFunctionGasEstimateTests is OGTHelper {
    function setUp() public {
        vm.startPrank(owner);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.mint(mintee, 100_000_000);
        token.enableTransfer();
        token.enableBurn();
        vm.stopPrank();
    }

    function testTransferGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.transfer(minter, amount);
    }

    function testTransferGasCost() public {
        vm.prank(mintee);
        token.transfer(minter, 10);
    }

    function testApproveAndTransferFromGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.approve(minter, amount);
        vm.prank(minter);
        token.transferFrom(mintee, minter, amount);
    }

    function testApproveAndTransferFromGasCost() public {
        vm.prank(mintee);
        token.approve(minter, 10);
        vm.prank(minter);
        token.transferFrom(mintee, minter, 10);
    }

    function testBurnGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.burn(amount);
    }

    function testBurnGasCost() public {
        vm.prank(mintee);
        token.burn(10);
    }

    function testApproveGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.approve(minter, amount);
    }

    function testApproveGasCost() public {
        vm.prank(mintee);
        token.approve(minter, 10);
    }

    function testIncreaseAllowanceGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.prank(mintee);
        token.increaseAllowance(minter, amount);
    }

    function testIncreaseAllowanceGasCost() public {
        vm.prank(mintee);
        token.increaseAllowance(minter, 10);
    }

    function testDecreaseAllowanceGasCostFuzzed(uint96 amount) public {
        vm.assume(amount < 100_000_000);
        vm.startPrank(mintee);
        token.approve(minter, amount);
        token.decreaseAllowance(minter, amount / 2);
    }

    function testDecreaseAllowanceGasCost() public {
        vm.startPrank(mintee);
        token.approve(minter, 15);
        token.decreaseAllowance(minter, 10);
    }
}
