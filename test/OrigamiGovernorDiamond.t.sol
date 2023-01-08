// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiGovernorDiamond.sol";
import "src/upgradeInitializers/GovernorDiamondInit.sol";

import "src/governor/CoreGovernanceFacet.sol";
import "src/governor/GovernorSettingsFacet.sol";

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

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

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

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        cuts[3] = governorSettingsFacetCut(governorSettingsFacet);

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

        bytes4[] memory selectors = new bytes4[](28);
        selectors[0] = facet.CANCELLER_ROLE.selector;
        selectors[1] = facet.DEFAULT_ADMIN_ROLE.selector;
        selectors[2] = facet.EIP712_TYPEHASH.selector;
        selectors[3] = facet.EXTENDED_BALLOT_TYPEHASH.selector;
        selectors[4] = facet.EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH.selector;
        selectors[5] = facet.castVote.selector;
        selectors[6] = facet.castVoteBySig.selector;
        selectors[7] = facet.castVoteWithReason.selector;
        selectors[8] = facet.castVoteWithReasonBySig.selector;
        selectors[9] = facet.domainSeparatorV4.selector;
        selectors[10] = facet.getRoleAdmin.selector;
        selectors[11] = facet.getVotes.selector;
        selectors[12] = facet.grantRole.selector;
        selectors[13] = facet.hasRole.selector;
        selectors[14] = facet.hasVoted.selector;
        selectors[15] = facet.hashProposal.selector;
        selectors[16] = facet.name.selector;
        selectors[17] = facet.nonces.selector;
        selectors[18] = facet.proposalDeadline.selector;
        selectors[19] = facet.proposalSnapshot.selector;
        selectors[20] = facet.propose.selector;
        selectors[21] = facet.proposeWithParams.selector;
        selectors[22] = facet.quorum.selector;
        selectors[23] = facet.renounceRole.selector;
        selectors[24] = facet.revokeRole.selector;
        selectors[25] = facet.state.selector;
        selectors[26] = facet.supportsInterface.selector;
        selectors[27] = facet.version.selector;

        coreGovernanceCut = IDiamondCut.FacetCut({
            facetAddress: coreGovernanceFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorSettingsFacetCut(GovernorSettingsFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorSettingsCut)
    {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = facet.proposalThreshold.selector;
        selectors[1] = facet.proposalThresholdToken.selector;
        selectors[2] = facet.setProposalThreshold.selector;
        selectors[3] = facet.setProposalThresholdToken.selector;
        selectors[4] = facet.setVotingDelay.selector;
        selectors[5] = facet.setVotingPeriod.selector;
        selectors[6] = facet.votingDelay.selector;
        selectors[7] = facet.votingPeriod.selector;

        governorSettingsCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function testRetrieveGovernorName() public {
        assertEq(CoreGovernanceFacet(address(origamiGovernorDiamond)).name(), "TestGovernor");
    }

    function testAdminHasDefaultAdminRole() public {
        assertTrue(CoreGovernanceFacet(address(origamiGovernorDiamond)).hasRole(0x00, admin));
    }

    function testRetrieveProposalThreshold() public {
        assertEq(GovernorSettingsFacet(address(origamiGovernorDiamond)).proposalThreshold(), 1);
    }
}
