// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "src/OrigamiMembershipToken.sol";
import "src/versions/OrigamiMembershipTokenBeforeInitialAuditFeedback.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

abstract contract OMTHelper {
  address owner = address(0x1);
  address minter = address(0x2);
  address mintee = address(0x3);
  address mintee2 = address(0x4);
  address revoker = address(0x5);

}

contract DeployMembershipTokenTest is Test {
  OrigamiMembershipToken impl;
  TransparentUpgradeableProxy proxy;
  OrigamiMembershipToken token;
  ProxyAdmin admin;

  function setUp() public {
    admin = new ProxyAdmin();
    impl = new OrigamiMembershipToken();
    proxy = new TransparentUpgradeableProxy(address(impl), address(admin), "");
    token = OrigamiMembershipToken(address(proxy));
  }

  function testCannotDeployToAddressZero() public {
    vm.expectRevert(bytes("Admin address cannot be zero"));
    token.initialize(address(0x0), "Deciduous Tree DAO Membership", "DTDM", "https://example.com/metadata");
  }

}

contract UpgradeMembershipTokenTest is Test, OMTHelper {
  OrigamiMembershipTokenBeforeInitialAuditFeedback implV1;
  OrigamiMembershipToken implV2;
  TransparentUpgradeableProxy proxy;
  OrigamiMembershipTokenBeforeInitialAuditFeedback tokenV1;
  OrigamiMembershipToken tokenV2;
  ProxyAdmin admin;

  event TransferEnabled(address indexed caller, bool value);

  function setUp() public {
    admin = new ProxyAdmin();
    implV1 = new OrigamiMembershipTokenBeforeInitialAuditFeedback();
    proxy = new TransparentUpgradeableProxy(address(implV1), address(admin), "");
    tokenV1 = OrigamiMembershipTokenBeforeInitialAuditFeedback(address(proxy));

    tokenV1.initialize(address(owner), "Deciduous Tree DAO Membership", "DTDM", "https://example.com/metadata");
  }

  function testCanInitialize() public {
    assertEq(tokenV1.name(), "Deciduous Tree DAO Membership");
  }

  function testCannotInitializeTwice() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    tokenV1.initialize(address(owner), "EVEN MOAR Deciduous Tree DAO Membership", "EMDTDM", "https://example.com/metadata");
  }

  function testCanUpgrade() public {
    implV2 = new OrigamiMembershipToken();
    admin.upgrade(proxy, address(implV2));
    tokenV2 = OrigamiMembershipToken(address(proxy));
    vm.prank(address(owner));

    vm.expectEmit(true, true, true, true, address(tokenV2));

    emit TransferEnabled(address(owner), true);

    tokenV2.enableTransfer();
  }
}