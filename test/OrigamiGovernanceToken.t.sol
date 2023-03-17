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

    function testTransferWhenDelegationExists() public {
        address other = address(0x7);

        // mint some more tokens as owner
        vm.warp(43);
        vm.prank(owner);
        token.mint(other, 100);

        // make sure mintee is self delegated
        vm.prank(mintee);
        token.delegate(mintee);

        // other should have balance of 100
        assertEq(token.balanceOf(other), 100);

        // delegate to mintee from other
        vm.startPrank(other);
        token.delegate(mintee);
        assertEq(token.getVotes(mintee), 200);
        assertEq(token.getVotes(other), 0);

        assertEq(token.balanceOf(other), 100);

        // transfer 10 tokens to mintee
        token.transfer(mintee, 10);

        // check that mintee has 110 votes
        assertEq(token.balanceOf(mintee), 110);
        // should still be 200 because it is self delegated
        assertEq(token.getVotes(mintee), 200);

        // // check that other has 90 as balance and 0 voting power
        // assertEq(token.balanceOf(mintee), 110);
        // assertEq(token.getVotes(other), 0);
        vm.stopPrank();
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
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 0);
    }

    function testAddTransferLock() public {
        assertEq(block.timestamp, 1);
        vm.prank(mintee);
        token.addTransferLock(100, 1000);
        uint256 amount = token.getTransferLockTotal(mintee);
        assertEq(amount, 100);
    }

    function testCannotAddTransferLockAmountHigherThanBalance() public {
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(101, 1000);
    }

    function testCannotTransferWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(100, 1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your unlocked balance");
        token.transfer(minter, 10);
    }

    function testCanTransferSurplusWhileLocked() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(90, 1704585600); // 2024-01-01
        vm.prank(mintee);
        token.transfer(minter, 10);
        assertEq(token.balanceOf(mintee), 90);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCanTransferAfterLockExpires() public {
        vm.warp(1673049600); // 2023-01-01
        vm.prank(mintee);
        token.addTransferLock(100, 1704585600); // 2024-01-01

        // timelock date is inclusive, so an attempt to transfer at the exact timelock time will fail
        vm.warp(1704585600); // 2024-01-01
        vm.prank(mintee);
        vm.expectRevert("TransferLock: this exceeds your unlocked balance");
        token.transfer(mintee, 10);

        // warp to the second immediately after the timelock expires and try again
        vm.prank(mintee);
        vm.warp(1704585601); // 2024-01-01
        token.transfer(minter, 10);
        assertEq(token.balanceOf(minter), 10);
    }

    function testCannotUnderflowAmount() public {
        vm.prank(mintee);
        token.addTransferLock(100, 1000);
        // we would get an underflow revert if we weren't checking the balance
        // exceeds the amount, since we do, we get the built-in revert about the
        // amount being too high
        vm.prank(mintee);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(minter, 200);
    }

    function testCanSetMultipleLocks() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(49, 2000);
        assertEq(token.getTransferLockTotal(mintee), 99);

        vm.warp(1001);
        assertEq(token.getTransferLockTotal(mintee), 49);
    }

    function testGetTransferLockTotalAt() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(25, 2000);
        token.addTransferLock(25, 3000);
        assertEq(token.getTransferLockTotalAt(mintee, 1), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1000), 100);
        assertEq(token.getTransferLockTotalAt(mintee, 1001), 50);
        assertEq(token.getTransferLockTotalAt(mintee, 2000), 50);
        assertEq(token.getTransferLockTotalAt(mintee, 2001), 25);
        assertEq(token.getTransferLockTotalAt(mintee, 3000), 25);
        assertEq(token.getTransferLockTotalAt(mintee, 3001), 0);
    }

    function testGetAvailableBalanceAt() public {
        vm.startPrank(mintee);
        token.addTransferLock(50, 1000);
        token.addTransferLock(25, 2000);
        token.addTransferLock(25, 3000);
        assertEq(token.getAvailableBalanceAt(mintee, 1), 0);
        assertEq(token.getAvailableBalanceAt(mintee, 1000), 0);
        assertEq(token.getAvailableBalanceAt(mintee, 1001), 50);
        assertEq(token.getAvailableBalanceAt(mintee, 2000), 50);
        assertEq(token.getAvailableBalanceAt(mintee, 2001), 75);
        assertEq(token.getAvailableBalanceAt(mintee, 3000), 75);
        assertEq(token.getAvailableBalanceAt(mintee, 3001), 100);
    }

    function testTransferWithLock() public {
        address recipient = address(0x42);
        vm.startPrank(mintee);
        token.transferWithLock(recipient, 10, 68);
        token.transferWithLock(recipient, 10, 419);
        vm.stopPrank();

        assertEq(token.balanceOf(recipient), 20);
        assertEq(token.getAvailableBalanceAt(recipient, 1), 0);
        assertEq(token.getAvailableBalanceAt(recipient, 69), 10);
        assertEq(token.getAvailableBalanceAt(recipient, 420), 20);
    }

    function testBatchTransferWithLocks() public {
        address treasury = address(0x42);
        vm.prank(owner);
        token.mint(treasury, 1000000);

        address[] memory recipients = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256[] memory timelocks = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            recipients[i] = (i % 2 == 0) ? address(0x42) : address(0x43);
        }

        for (uint256 i = 0; i < 10; i++) {
            amounts[i] = 100000;
        }

        uint256 counter = 0;
        for (uint256 i = 0; i < 10; i += 2) {
            uint256 timelock = counter * 100 + 100;
            timelocks[i] = timelock;
            timelocks[i + 1] = timelock;
            counter++;
        }

        vm.prank(treasury);
        token.batchTransferWithLocks(recipients, amounts, timelocks);

        assertEq(token.balanceOf(address(0x42)), 500000);
        assertEq(token.balanceOf(address(0x43)), 500000);

        assertEq(token.getAvailableBalanceAt(address(0x42), 1), 0);
        assertEq(token.getAvailableBalanceAt(address(0x42), 101), 100000);
        assertEq(token.getAvailableBalanceAt(address(0x42), 201), 200000);
        assertEq(token.getAvailableBalanceAt(address(0x42), 301), 300000);
        assertEq(token.getAvailableBalanceAt(address(0x42), 401), 400000);
        assertEq(token.getAvailableBalanceAt(address(0x42), 501), 500000);

        assertEq(token.getAvailableBalanceAt(address(0x43), 1), 0);
        assertEq(token.getAvailableBalanceAt(address(0x43), 101), 100000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 201), 200000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 301), 300000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 401), 400000);
        assertEq(token.getAvailableBalanceAt(address(0x43), 501), 500000);
    }
}
