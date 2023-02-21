// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title CheckpointVoteStorage
 * @dev This contract is used to store the checkpoints for votes and delegates
 * h/t YAM Protocol for the binary search approach:
 * https://github.com/yam-finance/yam-protocol/blob/3960424bdd5e921b0e283fa7feae3f996c480e49/contracts/token/YAMGovernance.sol
 */
library Checkpoints {
    bytes32 public constant CHECKPOINT_STORAGE_POSITION = keccak256("com.origami.ivotes.checkpoints");
    bytes32 public constant DELEGATE_STORAGE_POSITION = keccak256("com.origami.ivotes.delegates");

    /**
     * @dev Emitted when an account changes their delegate.
     */
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.
     */
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    struct Checkpoint {
        uint256 timestamp;
        uint256 votes;
    }

    struct CheckpointStorage {
        /**
         * @dev The number of checkpoints for the total supply of tokens
         */
        uint32 supplyCheckpointsCount;
        /**
         * @notice An indexed mapping of checkpoints for the total supply of tokens
         * @dev this allows for 4.3 billion supply checkpoints
         */
        mapping(uint32 => Checkpoint) supplyCheckpoints;
        /**
         * @dev The number of checkpoints for each `account`
         */
        mapping(address => uint32) voterCheckpointsCount;
        /**
         * @notice An indexed mapping of checkpoints for each account
         * @dev this allows for 4.3 billion checkpoints per account
         */
        mapping(address => mapping(uint32 => Checkpoint)) voterCheckpoints;
    }

    struct DelegateStorage {
        mapping(address => address) delegates;
        mapping(address => uint256) nonces;
    }

    function checkpointStorage() internal pure returns (CheckpointStorage storage cs) {
        bytes32 position = CHECKPOINT_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            cs.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    function getWeight(mapping(uint32 => Checkpoint) storage checkpoints, uint32 count)
        internal
        view
        returns (uint256 weight)
    {
        if (count > 0) {
            weight = checkpoints[count - 1].votes;
        } else {
            weight = 0;
        }
    }

    function getPastWeight(mapping(uint32 => Checkpoint) storage checkpoints, uint32 count, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // If there are no checkpoints, return 0
        if (count == 0) {
            return 0;
        }

        // Most recent checkpoint is older than specified timestamp, use it
        if (checkpoints[count - 1].timestamp <= timestamp) {
            return checkpoints[count - 1].votes;
        }

        // First checkpoint is after the specified timestamp
        if (checkpoints[0].timestamp > timestamp) {
            return 0;
        }

        // Failing the above, binary search the checkpoints
        uint32 lower = 0;
        uint32 upper = count - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // rounds up
            Checkpoint memory cp = checkpoints[center];
            if (cp.timestamp == timestamp) {
                return cp.votes;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[lower].votes;
    }

    function getVotes(address account) internal view returns (uint256 votes) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.voterCheckpointsCount[account];
        return getWeight(cs.voterCheckpoints[account], count);
    }

    function getPastVotes(address account, uint256 timestamp) internal view returns (uint256 votes) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.voterCheckpointsCount[account];
        return getPastWeight(cs.voterCheckpoints[account], count, timestamp);
    }

    function getTotalSupply() internal view returns (uint256 supply) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.supplyCheckpointsCount;
        return getWeight(cs.supplyCheckpoints, count);
    }

    function getPastTotalSupply(uint256 timestamp) internal view returns (uint256 supply) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.supplyCheckpointsCount;
        return getPastWeight(cs.supplyCheckpoints, count, timestamp);
    }

    function delegateStorage() internal pure returns (DelegateStorage storage ds) {
        bytes32 position = DELEGATE_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            ds.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    function delegates(address account) internal view returns (address) {
        DelegateStorage storage ds = delegateStorage();
        return ds.delegates[account];
    }

    function writeCheckpoint(address delegatee, uint256 oldVotes, uint256 newVotes) internal {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 checkpointCount = cs.voterCheckpointsCount[delegatee];
        cs.voterCheckpoints[delegatee][checkpointCount] = Checkpoint(block.timestamp, newVotes);
        cs.voterCheckpointsCount[delegatee] = checkpointCount + 1;
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function writeSupplyCheckpoint(uint256 newSupply) internal {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 checkpointCount = cs.supplyCheckpointsCount;
        cs.supplyCheckpoints[checkpointCount] = Checkpoint(block.timestamp, newSupply);
        cs.supplyCheckpointsCount = checkpointCount + 1;
    }

    function moveDelegation(address oldDelegate, address newDelegate, uint256 amount) internal {
        if (oldDelegate != newDelegate && amount > 0) {
            if (oldDelegate != address(0)) {
                // decrease old delegate
                uint256 oldVotes = getVotes(oldDelegate);
                uint256 newVotes = oldVotes - amount;
                writeCheckpoint(oldDelegate, oldVotes, newVotes);
            }

            if (newDelegate != address(0)) {
                // increase new delegate
                uint256 oldVotes = getVotes(newDelegate);
                uint256 newVotes = oldVotes + amount;
                writeCheckpoint(newDelegate, oldVotes, newVotes);
            }
        }
    }

    function transferVotingUnits(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            writeSupplyCheckpoint(getTotalSupply() + amount);
        }
        if (to == address(0)) {
            writeSupplyCheckpoint(getTotalSupply() - amount);
        }
        moveDelegation(delegates(from), delegates(to), amount);
    }

    function delegate(address delegator, address delegatee) internal {
        DelegateStorage storage ds = delegateStorage();
        address currentDelegate = ds.delegates[delegator];
        ds.delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }
}
