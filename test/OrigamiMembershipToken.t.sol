// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "@std/Test.sol";
import "src/OrigamiMembershipToken.sol";
import "src/versions/OrigamiMembershipTokenBeforeInitialAuditFeedback.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract AddressHelper {
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public mintee = address(0x3);
    address public recipient = address(0x4);
    address public revoker = address(0x5);
    address public pauser = address(0x6);
}

abstract contract OMTHelper is AddressHelper {
    OrigamiMembershipToken public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiMembershipToken public token;
    ProxyAdmin public admin;

    constructor() {
        admin = new ProxyAdmin();
        impl = new OrigamiMembershipToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        token = OrigamiMembershipToken(address(proxy));
        token.initialize(
            owner,
            "Deciduous Tree DAO Membership",
            "DTDM",
            "https://example.com/metadata/"
        );
    }
}

contract DeployMembershipTokenTest is Test {
    OrigamiMembershipToken public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiMembershipToken public token;
    ProxyAdmin public admin;

    function setUp() public {
        admin = new ProxyAdmin();
        impl = new OrigamiMembershipToken();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        token = OrigamiMembershipToken(address(proxy));
    }

    function testCannotDeployToAddressZero() public {
        vm.expectRevert(bytes("Admin address cannot be zero"));
        token.initialize(
            address(0x0),
            "Deciduous Tree DAO Membership",
            "DTDM",
            "https://example.com/metadata"
        );
    }
}

contract UpgradeMembershipTokenTest is Test, AddressHelper {
    OrigamiMembershipTokenBeforeInitialAuditFeedback public implV1;
    OrigamiMembershipToken public implV2;
    TransparentUpgradeableProxy public proxy;
    OrigamiMembershipTokenBeforeInitialAuditFeedback public tokenV1;
    OrigamiMembershipToken public tokenV2;
    ProxyAdmin public admin;

    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        admin = new ProxyAdmin();
        implV1 = new OrigamiMembershipTokenBeforeInitialAuditFeedback();
        proxy = new TransparentUpgradeableProxy(
            address(implV1),
            address(admin),
            ""
        );
        tokenV1 = OrigamiMembershipTokenBeforeInitialAuditFeedback(
            address(proxy)
        );

        tokenV1.initialize(
            owner,
            "Deciduous Tree DAO Membership",
            "DTDM",
            "https://example.com/metadata"
        );
    }

    function testCanInitialize() public {
        assertEq(tokenV1.name(), "Deciduous Tree DAO Membership");
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        tokenV1.initialize(
            owner,
            "EVEN MOAR Deciduous Tree DAO Membership",
            "EMDTDM",
            "https://example.com/metadata/"
        );
    }

    function testCanUpgrade() public {
        implV2 = new OrigamiMembershipToken();
        admin.upgrade(proxy, address(implV2));
        tokenV2 = OrigamiMembershipToken(address(proxy));
        vm.prank(owner);

        vm.expectEmit(true, true, true, true, address(tokenV2));

        // TransferEnabled does not exist in tokenV1, so it being emited here is proof that the upgrade worked
        emit TransferEnabled(owner, true);

        tokenV2.enableTransfer();
    }
}

contract MintMembershipTokenTest is OMTHelper, Test {
    event Mint(address indexed _to, uint256 indexed _tokenId);

    function setUp() public {
        vm.startPrank(owner);
    }

    function testMint() public {
        token.safeMint(mintee);
        assertEq(token.balanceOf(mintee), 1);
        assertEq(token.ownerOf(1), mintee);
        assertEq(token.tokenURI(1), "https://example.com/metadata/1");
    }

    function testCanOnlyMintOnce() public {
        token.safeMint(mintee);
        vm.expectRevert(bytes("Holders may only have one token"));
        token.safeMint(mintee);
    }

    function testEmitsMintEvent() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Mint(mintee, 1);
        token.safeMint(mintee);
    }
}

contract MetadataMembershipTokenTest is OMTHelper, Test {
    event BaseURIChanged(address indexed caller, string value);

    function setUp() public {
        vm.startPrank(owner);
    }

    function testRevertsOnInvalidTokenId() public {
        vm.expectRevert(bytes("Invalid token ID"));
        token.tokenURI(0);
        vm.expectRevert(bytes("Invalid token ID"));
        token.tokenURI(2);
    }

    function testRevertsWhenNonAdminChangesBaseURI() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.setBaseURI("https://example.com/metadata/");
    }

    function testSetBaseURIEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit BaseURIChanged(owner, "https://deciduous.tree/metadata/");
        token.setBaseURI("https://deciduous.tree/metadata/");
    }

    function testSetBaseURIAffectsTokenUri() public {
        token.setBaseURI("https://deciduous.tree/metadata/");
        token.safeMint(mintee);
        assertEq(token.tokenURI(1), "https://deciduous.tree/metadata/1");
    }
}

contract PausingMembershipTokenTest is OMTHelper, Test {
    event Paused(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
    }

    function testRevertsWhenNonAdminPauses() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.pause();
    }

    function testRevertsWhenNonAdminUnpauses() public {
        token.pause();
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"
            )
        );
        token.unpause();
    }

    function testRevertsMintWhenPaused() public {
        token.pause();
        vm.expectRevert(bytes("Pausable: paused"));
        token.safeMint(mintee);
    }

    function testEmitsPausedEvent() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Paused(owner, true);
        token.pause();
    }

    function testEmitsUnpausedEvent() public {
        token.pause();
        vm.expectEmit(true, true, true, true, address(token));
        emit Paused(owner, false);
        token.unpause();
    }

    function testCanUnpause() public {
        token.pause();
        token.unpause();
        token.safeMint(mintee);
        assertEq(token.balanceOf(mintee), 1);
    }

    function testPauserCanPause() public {
        token.grantRole(token.PAUSER_ROLE(), pauser);
        token.pause();
        token.unpause();
        token.safeMint(mintee);
        assertEq(token.balanceOf(mintee), 1);
    }
}

contract TransferrabilityMembershipTokenTest is OMTHelper, Test {
    event TransferEnabled(address indexed caller, bool value);

    function setUp() public {
        vm.startPrank(owner);
    }

    function testRevertsWhenNonAdminEnablesTransfer() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.enableTransfer();
    }

    function testRevertsWhenNonAdminDisablesTransfer() public {
        token.enableTransfer();
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        token.disableTransfer();
    }

    function testRevertsTransferWhenDisabled() public {
        vm.expectRevert(bytes("Transferrable: transfers are disabled"));
        token.safeTransferFrom(mintee, recipient, 1);
    }

    function testEmitsTransferEnabledEvent() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, true);
        token.enableTransfer();
    }

    function testEmitsTransferDisabledEvent() public {
        token.enableTransfer();
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferEnabled(owner, false);
        token.disableTransfer();
    }

    function testCanDisableTransfer() public {
        token.enableTransfer();
        token.disableTransfer();

        // unsafe base signature
        vm.expectRevert(bytes("Transferrable: transfers are disabled"));
        token.transferFrom(mintee, recipient, 1);

        // base signature
        vm.expectRevert(bytes("Transferrable: transfers are disabled"));
        token.safeTransferFrom(mintee, recipient, 1);

        // bulk transfer signature
        vm.expectRevert(bytes("Transferrable: transfers are disabled"));
        token.safeTransferFrom(mintee, recipient, 1);

        // bulk transfer and call signature
        vm.expectRevert(bytes("Transferrable: transfers are disabled"));
        token.safeTransferFrom(mintee, recipient, 1, bytes("0x"));
    }

    function testCanTransferWhenEnabled() public {
        token.safeMint(mintee);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(mintee);
        token.safeTransferFrom(mintee, recipient, 1);
        assertEq(token.balanceOf(recipient), 1);
    }

    function testOnlyOwnerCanTransferWhenEnabled() public {
        token.safeMint(mintee);
        token.enableTransfer();
        vm.stopPrank();
        vm.prank(recipient);
        vm.expectRevert(
            bytes("ERC721: caller is not token owner nor approved")
        );
        token.transferFrom(mintee, recipient, 1);
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

    function testMinterCanTransferWhenNontransferrable() public {
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.prank(minter);
        // mint is a transfer
        token.safeMint(mintee);
        assertEq(token.balanceOf(mintee), 1);
    }
}

contract RevokeMembershipTokenTest is OMTHelper, Test {
    function setUp() public {
        vm.startPrank(owner);
    }

    function testRevertsWhenNonAdminRevokes() public {
        vm.stopPrank();
        vm.expectRevert(
            bytes(
                "AccessControl: account 0xb4c79dab8f259c7aee6e5b2aa729821864227e84 is missing role 0xce3f34913921da558f105cefb578d87278debbbd073a8d552b5de0d168deee30"
            )
        );
        token.revoke(mintee);
    }

    function testRevertsWhenRevokingNonexistentToken() public {
        vm.expectRevert(bytes("Revoke: cannot revoke"));
        token.revoke(mintee);
    }

    function testRevertsWhenRevokingAlreadyRevokedToken() public {
        token.safeMint(mintee);
        token.revoke(mintee);
        vm.expectRevert(bytes("Revoke: cannot revoke"));
        token.revoke(mintee);
    }

    function testAdminCanRevoke() public {
        token.safeMint(mintee);
        token.revoke(mintee);
        assertEq(token.balanceOf(mintee), 0);
    }

    function testRevokerCanRevoke() public {
        token.safeMint(mintee);
        token.grantRole(token.REVOKER_ROLE(), revoker);
        vm.stopPrank();
        vm.prank(revoker);
        token.revoke(mintee);
        assertEq(token.balanceOf(mintee), 0);
    }
}
