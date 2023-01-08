// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernorDiamond.sol";
import "src/upgradeInitializers/GovernorDiamondInit.sol";

import "src/governor/GovernorCoreFacet.sol";
import "src/governor/GovernorSettingsFacet.sol";
import "src/governor/GovernorTimelockControlFacet.sol";
import "src/utils/DiamondDeployHelper.sol";

import "@std/Test.sol";

import "@diamond/facets/DiamondCutFacet.sol";
import "@diamond/facets/DiamondLoupeFacet.sol";
import "@diamond/facets/OwnershipFacet.sol";

import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract GovDiamondAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public admin = address(0x3);
}

contract DeployOrigamiGovernorDiamond is GovDiamondAddressHelper, Test {
    OrigamiGovernanceToken public govTokenImpl;
    TransparentUpgradeableProxy public govTokenProxy;
    OrigamiGovernanceToken public govToken;
    ProxyAdmin public govTokenAdmin;

    OrigamiTimelock public timelockImpl;
    TransparentUpgradeableProxy public timelockProxy;
    OrigamiTimelock public timelock;
    ProxyAdmin public timelockAdmin;

    OrigamiGovernorDiamond public origamiGovernorDiamond;

    constructor() {
        vm.startPrank(deployer);

        // deploy gov token via proxy
        govTokenAdmin = new ProxyAdmin();
        govTokenImpl = new OrigamiGovernanceToken();
        govTokenProxy = new TransparentUpgradeableProxy(
            address(govTokenImpl),
            address(govTokenAdmin),
            ""
        );
        govToken = OrigamiGovernanceToken(address(govTokenProxy));
        govToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", 10000000000000000000000000000);

        GovernorDiamondInit diamondInit = new GovernorDiamondInit();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        cuts[0] = DiamondDeployHelper.diamondLoupeFacetCut(address(diamondLoupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        cuts[1] = DiamondDeployHelper.ownershipFacetCut(address(ownershipFacet));

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();

        // deploy timelock via proxy
        timelockAdmin = new ProxyAdmin();
        timelockImpl = new OrigamiTimelock();
        timelockProxy = new TransparentUpgradeableProxy(
            address(timelockImpl),
            address(timelockAdmin),
            ""
        );
        timelock = OrigamiTimelock(payable(timelockProxy));

        // initialize the timelock after we have an address for the governor
        address[] memory proposers = new address[](1);
        proposers[0] = address(governorCoreFacet);
        address[] memory executors = new address[](1);
        executors[0] = address(governorCoreFacet);

        timelock.initialize(1 days, proposers, executors);

        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(governorCoreFacet);

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(governorSettingsFacet);

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(governorTimelockControlFacet);

        origamiGovernorDiamond = new OrigamiGovernorDiamond(owner, address(diamondCutFacet));

        vm.stopPrank();

        vm.prank(owner);
        DiamondCutFacet(address(origamiGovernorDiamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeWithSignature(
                "init(string,address,address,address,uint24,uint24,uint8,uint16)",
                "TestGovernor",
                admin,
                address(timelock),
                address(govToken),
                7 days,
                7 days,
                10,
                1
            )
        );
    }

    function testRetrieveGovernorName() public {
        assertEq(GovernorCoreFacet(address(origamiGovernorDiamond)).name(), "TestGovernor");
    }

    function testAdminHasDefaultAdminRole() public {
        assertTrue(GovernorCoreFacet(address(origamiGovernorDiamond)).hasRole(0x00, admin));
    }

    function testRetrieveProposalThreshold() public {
        assertEq(GovernorSettingsFacet(address(origamiGovernorDiamond)).proposalThreshold(), 1);
    }
}
