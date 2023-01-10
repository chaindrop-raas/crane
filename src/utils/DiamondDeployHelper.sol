// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/GovernorCoreFacet.sol";
import "src/governor/GovernorSettingsFacet.sol";
import "src/governor/GovernorTimelockControlFacet.sol";

import "@diamond/facets/DiamondCutFacet.sol";
import "@diamond/facets/DiamondLoupeFacet.sol";
import "@diamond/facets/OwnershipFacet.sol";

/**
 * @author Origami
 * @dev Common functions for the Governor modules.
 * @custom:security-contact contract-security@joinorigami.com
 */
library DiamondDeployHelper {
    function diamondLoupeFacetCut(address diamondLoupeFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory diamondLoupeCut)
    {
        bytes4[] memory diamondLoupeSelectors = new bytes4[](5);
        diamondLoupeSelectors[0] = DiamondLoupeFacet.facetAddress.selector;
        diamondLoupeSelectors[1] = DiamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[2] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[3] = DiamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
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

    function governorCoreFacetCut(GovernorCoreFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorCoreCut)
    {
        bytes4[] memory selectors = new bytes4[](27);
        selectors[0] = facet.CANCELLER_ROLE.selector;
        selectors[1] = facet.DEFAULT_ADMIN_ROLE.selector;
        selectors[2] = facet.EIP712_TYPEHASH.selector;
        selectors[3] = facet.EXTENDED_IDEMPOTENT_BALLOT_TYPEHASH.selector;
        selectors[4] = facet.castVote.selector;
        selectors[5] = facet.castVoteBySig.selector;
        selectors[6] = facet.castVoteWithReason.selector;
        selectors[7] = facet.castVoteWithReasonBySig.selector;
        selectors[8] = facet.domainSeparatorV4.selector;
        selectors[9] = facet.getRoleAdmin.selector;
        selectors[10] = facet.getVotes.selector;
        selectors[11] = facet.grantRole.selector;
        selectors[12] = facet.hasRole.selector;
        selectors[13] = facet.hasVoted.selector;
        selectors[14] = facet.hashProposal.selector;
        selectors[15] = facet.name.selector;
        selectors[16] = facet.nonces.selector;
        selectors[17] = facet.proposalDeadline.selector;
        selectors[18] = facet.proposalSnapshot.selector;
        selectors[19] = facet.proposalVotes.selector;
        selectors[20] = facet.propose.selector;
        selectors[21] = facet.proposeWithParams.selector;
        selectors[22] = facet.quorum.selector;
        selectors[23] = facet.renounceRole.selector;
        selectors[24] = facet.revokeRole.selector;
        selectors[25] = facet.state.selector;
        selectors[26] = facet.version.selector;

        governorCoreCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorSettingsFacetCut(GovernorSettingsFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorSettingsCut)
    {
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = facet.proposalThreshold.selector;
        selectors[1] = facet.proposalThresholdToken.selector;
        selectors[2] = facet.quorumNumerator.selector;
        selectors[3] = facet.setProposalThreshold.selector;
        selectors[4] = facet.setProposalThresholdToken.selector;
        selectors[5] = facet.setQuorumNumerator.selector;
        selectors[6] = facet.setVotingDelay.selector;
        selectors[7] = facet.setVotingPeriod.selector;
        selectors[8] = facet.votingDelay.selector;
        selectors[9] = facet.votingPeriod.selector;

        governorSettingsCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorTimelockControlFacetCut(GovernorTimelockControlFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorTimelockControlCut)
    {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = facet.cancel.selector;
        selectors[1] = facet.execute.selector;
        selectors[2] = facet.proposalEta.selector;
        selectors[3] = facet.queue.selector;
        selectors[4] = facet.timelock.selector;
        selectors[5] = facet.updateTimelock.selector;

        governorTimelockControlCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
