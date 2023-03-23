// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorCoreFacet} from "src/governor/GovernorCoreFacet.sol";
import {GovernorSettingsFacet} from "src/governor/GovernorSettingsFacet.sol";
import {GovernorTimelockControlFacet} from "src/governor/GovernorTimelockControlFacet.sol";

import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";

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
        bytes4[] memory selectors = new bytes4[](34);
        selectors[0] = facet.CANCELLER_ROLE.selector;
        selectors[1] = facet.DEFAULT_ADMIN_ROLE.selector;
        selectors[2] = facet.EIP712_TYPEHASH.selector;
        selectors[3] = facet.IDEMPOTENT_BALLOT_TYPEHASH.selector;
        selectors[4] = facet.IDEMPOTENT_PROPOSAL_TYPEHASH.selector;
        selectors[5] = facet.castVote.selector;
        selectors[6] = facet.castVoteBySig.selector;
        selectors[7] = facet.castVoteWithReason.selector;
        selectors[8] = facet.castVoteWithReasonBySig.selector;
        selectors[9] = facet.domainSeparatorV4.selector;
        selectors[10] = facet.getAccountNonce.selector;
        selectors[11] = facet.getRoleAdmin.selector;
        selectors[12] = facet.getVotes.selector;
        selectors[13] = facet.grantRole.selector;
        selectors[14] = facet.hasRole.selector;
        selectors[15] = facet.hasVoted.selector;
        selectors[16] = facet.hashProposal.selector;
        selectors[17] = facet.isProposalTokenEnabled.selector;
        selectors[18] = facet.name.selector;
        selectors[19] = facet.proposalDeadline.selector;
        selectors[20] = facet.proposalSnapshot.selector;
        selectors[21] = facet.proposalVotes.selector;
        selectors[22] = facet.propose.selector;
        selectors[23] = facet.proposeBySig.selector;
        selectors[24] = facet.proposeWithParams.selector;
        selectors[25] = facet.proposeWithParamsBySig.selector;
        selectors[26] = facet.proposeWithTokenAndCountingStrategy.selector;
        selectors[27] = facet.proposeWithTokenAndCountingStrategyBySig.selector;
        selectors[28] = facet.quorum.selector;
        selectors[29] = facet.renounceRole.selector;
        selectors[30] = facet.revokeRole.selector;
        selectors[31] = facet.simpleWeight.selector;
        selectors[32] = facet.state.selector;
        selectors[33] = facet.version.selector;

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
        bytes4[] memory selectors = new bytes4[](19);
        selectors[0] = facet.defaultCountingStrategy.selector;
        selectors[1] = facet.defaultProposalToken.selector;
        selectors[2] = facet.enableProposalToken.selector;
        selectors[3] = facet.governanceToken.selector;
        selectors[4] = facet.membershipToken.selector;
        selectors[5] = facet.proposalThreshold.selector;
        selectors[6] = facet.proposalThresholdToken.selector;
        selectors[7] = facet.quorumNumerator.selector;
        selectors[8] = facet.setDefaultCountingStrategy.selector;
        selectors[9] = facet.setDefaultProposalToken.selector;
        selectors[10] = facet.setGovernanceToken.selector;
        selectors[11] = facet.setMembershipToken.selector;
        selectors[12] = facet.setProposalThreshold.selector;
        selectors[13] = facet.setProposalThresholdToken.selector;
        selectors[14] = facet.setQuorumNumerator.selector;
        selectors[15] = facet.setVotingDelay.selector;
        selectors[16] = facet.setVotingPeriod.selector;
        selectors[17] = facet.votingDelay.selector;
        selectors[18] = facet.votingPeriod.selector;

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
