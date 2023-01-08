// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernorDiamond.sol";
import "src/upgradeInitializers/GovernorDiamondInit.sol";
import "src/governor/CoreGovernanceFacet.sol";

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

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        cuts[0] = diamondLoupeFacetCut(address(diamondLoupeFacet));
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        cuts[1] = ownershipFacetCut(address(ownershipFacet));

        OrigamiTimelock origamiTimelock = new OrigamiTimelock();

        CoreGovernanceFacet coreGovernanceFacet = new CoreGovernanceFacet();

        // initialize the timelock after we have an address for the governor
        address[] memory proposers = new address[](1);
        proposers[0] = address(coreGovernanceFacet);
        address[] memory executors = new address[](1);
        executors[0] = address(coreGovernanceFacet);

        // FIXME: contract is already initialized
        // origamiTimelock.initialize(1 days, proposers, executors);

        cuts[2] = coreGovernanceFacetCut(address(coreGovernanceFacet));

        origamiGovernorDiamond = new OrigamiGovernorDiamond(owner, address(diamondCutFacet));
        vm.stopPrank();
        vm.startPrank(owner);
        DiamondCutFacet(address(origamiGovernorDiamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeWithSignature(
                "init(string,address,address,address,uint24,uint24,uint8,uint16)",
                "TestGovernor",
                admin,
                address(origamiTimelock),
                address(govToken),
                7 days,
                7 days,
                10,
                1
            )
        );
        vm.stopPrank();
    }

    function diamondLoupeFacetCut(address diamondLoupeFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory diamondLoupeCut)
    {
        bytes4[] memory diamondLoupeSelectors = new bytes4[](4);
        diamondLoupeSelectors[0] = IDiamondLoupe.facets.selector;
        diamondLoupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        diamondLoupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        diamondLoupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        diamondLoupeCut = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondLoupeSelectors
        });
    }

    function ownershipFacetCut(address ownershipFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory ownershipCut)
    {
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;
        ownershipCut = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
    }

    function coreGovernanceFacetCut(address coreGovernanceFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory coreGovernanceCut)
    {
        CoreGovernanceFacet facet = CoreGovernanceFacet(coreGovernanceFacet);
        bytes4[] memory coreGovernanceSelectors = new bytes4[](7);
        coreGovernanceSelectors[0] = facet.name.selector;
        coreGovernanceSelectors[1] = facet.hashProposal.selector;
        coreGovernanceSelectors[2] = facet.state.selector;
        coreGovernanceSelectors[3] = facet.proposalSnapshot.selector;
        coreGovernanceSelectors[4] = facet.proposalDeadline.selector;
        coreGovernanceSelectors[5] = facet.hasRole.selector;
        coreGovernanceSelectors[6] = facet.grantRole.selector;
        coreGovernanceCut = IDiamondCut.FacetCut({
            facetAddress: coreGovernanceFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: coreGovernanceSelectors
        });
    }

    function testRetrieveGovernorName() public {
        assertEq(CoreGovernanceFacet(address(origamiGovernorDiamond)).name(), "TestGovernor");
    }

    function testAdminHasDefaultAdminRole() public {
        assertTrue(CoreGovernanceFacet(address(origamiGovernorDiamond)).hasRole(0x00, admin));
    }
}
