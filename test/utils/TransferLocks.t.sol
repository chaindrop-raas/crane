// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {TransferLocks} from "src/utils/TransferLocks.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {Test, console2} from "@std/Test.sol";

contract TransferLocksTestHelper is Test {
    TransferLocks public impl;
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public proxy;
    TransferLocks public token;

    address public deployer = address(0x1);
    address public owner = address(0x2);

    address public mintee = address(0x3);

    constructor() {
        vm.startPrank(owner);
        impl = new TransferLocks();
        proxyAdmin = new ProxyAdmin();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            ""
        );
        token = TransferLocks(address(proxy));
        token.initialize(owner, "TransferLocksTest", "TLT", 1000000 ether);
        token.mint(mintee, 100);
        token.enableTransfer();
        vm.stopPrank();
    }
}

contract TransferLocksBaseTest is TransferLocksTestHelper {
    function testCannotAddLockThatExceedsCurrentAvailableBalance() public {
        vm.warp(1673049600); // 2023-01-01

        // start off with 100 tokens
        assertEq(token.balanceOf(mintee), 100);

        // add a lock for the full amount until March 21, 2023
        vm.prank(mintee);
        token.addTransferLock(100, 1679426715); //2023-03-21

        assertEq(token.balanceOf(mintee), 100);
        assertEq(token.getTransferLockTotalAt(mintee, block.timestamp), 100);
        assertEq(token.getAvailableBalanceAt(mintee, block.timestamp), 0);

        // add another lock for full amount for a day longer than the last
        vm.prank(mintee);
        vm.expectRevert("TransferLock: amount cannot exceed available balance");
        token.addTransferLock(100, 1679513115); //2023-03-22
    }
}
