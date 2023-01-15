// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/lib/Voting.sol";
import "src/governor/lib/TokenWeightStrategy.sol";
import "src/utils/GovernorStorage.sol";

library SingleChoice {
    bytes32 public constant SINGLE_CHOICE_STORAGE_POSITION = keccak256("com.origami.governor.counting.singlechoice");

    struct SingleChoiceStorage {
        mapping(uint256 => string[16]) options;
    }

    /**
     * @dev returns the SingleChoiceStorage location.
     */
    function configStorage() internal pure returns (SingleChoiceStorage storage scs) {
        bytes32 position = SINGLE_CHOICE_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            scs.slot := position
        }
    }

    function encodeVote(uint8 option, uint256 weight, uint256 calculatedWeight) internal pure returns (bytes memory) {
        return abi.encode(option, weight, calculatedWeight);
    }

    function decodeVote(bytes memory vote)
        internal
        pure
        returns (uint8 option, uint256 weight, uint256 calculatedWeight)
    {
        (option, weight, calculatedWeight) = abi.decode(vote, (uint8, uint256, uint256));
        return (option, weight, 0);
    }

    function setVote(uint256 proposalId, address account, uint8 option, uint256 weight) internal {
        require(option < 16, "Governor: option out of range");
        bytes4 weightingSelector = GovernorStorage.proposal(proposalId).countingStrategy;
        uint256 calculatedWeight = TokenWeightStrategy.applyStrategy(weight, weightingSelector);
        Voting.setVote(proposalId, account, encodeVote(option, weight, calculatedWeight));
    }

    function getVote(uint256 proposalId, address account) internal view returns (uint8, uint256, uint256) {
        (uint8 option, uint256 weight, uint256 calculatedWeight) =
            abi.decode(Voting.getVote(proposalId, account), (uint8, uint256, uint256));
        return (option, weight, calculatedWeight);
    }

    function proposalVotes(uint256 proposalId)
        internal
        view
        returns (uint8[] memory options, uint256[] memory calculatedWeights)
    {
        address[] memory voters = GovernorStorage.proposalVoters(proposalId);
        for(uint256 i = 0; i < voters.length; i++) {
            (uint8 _option,, uint256 calculatedWeight) = getVote(proposalId, voters[i]);
            options[i] = _option;
            calculatedWeights[i] = calculatedWeight;
        }
    }

    function quorumReached(uint256 proposalId) internal view returns (bool) {
        // sum the calculated weights of all votes for the proposal
        uint256 totalWeight = 0;
        (, uint256[] memory calculatedWeights) = proposalVotes(proposalId);
        for(uint256 i = 0; i < calculatedWeights.length; i++) {
            totalWeight += calculatedWeights[i];
        }
        bytes4 weightStrategy = GovernorStorage.proposal(proposalId).countingStrategy;
        uint256 proposalQuorum = GovernorQuorum.quorum(proposalId);
        uint256 weightedQuorum = TokenWeightStrategy.applyStrategy(proposalQuorum, weightStrategy);
        return totalWeight >= weightedQuorum;
    }

    function winningOption(uint256 proposalId) internal view returns (uint8) {
        // find the index of the largest calculated weight
        (uint8[] memory options, uint256[] memory calculatedWeights) = proposalVotes(proposalId);
        uint256 largestWeight = 0;
        uint256 largestWeightIndex = 0;
        for(uint256 i = 0; i < calculatedWeights.length; i++) {
            if(calculatedWeights[i] > largestWeight) {
                largestWeight = calculatedWeights[i];
                largestWeightIndex = i;
            }
        }
        return options[largestWeightIndex];
    }
}
