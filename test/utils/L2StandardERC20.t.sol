// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/utils/L2StandardERC20.sol";

import "src/interfaces/utils/IL2StandardERC20.sol";
import "@std/Test.sol";

abstract contract L2StandardERC20Helper {
    address public deployer = address(0x1);
    address public owner = address(0x2);

    address public token = address(0x3);
    address public bridge = address(0x4);
}

contract L2ChildContract is L2StandardERC20, L2StandardERC20Helper {
    constructor() {
        setL1Token(token);
        setL2Bridge(bridge);
    }
}

contract TestL2ChildContract is L2StandardERC20Helper, Test {
    event Mint(address indexed _account, uint256 _amount);
    event Burn(address indexed _account, uint256 _amount);

    L2ChildContract public child;

    function setUp() public {
        child = new L2ChildContract();
    }

    function testL1Token() public {
        assertEq(child.l1Token(), token);
    }

    function testL2Bridge() public {
        assertEq(child.l2Bridge(), bridge);
    }

    function testSetL1Token() public {
        child.setL1Token(address(0x5));
        assertEq(child.l1Token(), address(0x5));
    }

    function testSetL2Bridge() public {
        child.setL2Bridge(address(0x6));
        assertEq(child.l2Bridge(), address(0x6));
    }

    function testMint() public {
        vm.prank(bridge);
        vm.expectEmit(true, true, true, true, address(child));
        emit Mint(owner, 100);
        child.mint(owner, 100);
    }

    function testBurn() public {
        vm.startPrank(bridge);
        child.mint(owner, 100);
        vm.expectEmit(true, true, true, true, address(child));
        emit Burn(owner, 100);
        child.burn(owner, 100);
    }

    function testNonBridgeMint() public {
        vm.prank(owner);
        vm.expectRevert("L2StandardERC20: only L2 Bridge can mint and burn");
        child.mint(owner, 100);
    }

    function testNonBridgeBurn() public {
        vm.prank(bridge);
        child.mint(owner, 100);
        vm.prank(owner);
        vm.expectRevert("L2StandardERC20: only L2 Bridge can mint and burn");
        child.burn(owner, 100);
    }

    function testSupportsIL2StandardERC20() public {
        assertTrue(child.supportsInterface(type(IL2StandardERC20).interfaceId));
        assertTrue(child.supportsInterface(type(IERC165).interfaceId));
        assertTrue(child.supportsInterface(type(ILegacyMintableERC20).interfaceId));
        // assert the bytes4 values of the interface ids since the bridge depends on them
        assertEq(child.supportsInterface(0x01ffc9a7), true); // IERC165
        assertEq(child.supportsInterface(0x1d1d8b63), true); // ILegacyMintableERC20
    }
}
