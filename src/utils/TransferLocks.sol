// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/TransferLocksStorage.sol";
import "src/interfaces/ITransferLocks.sol";
import "@diamond/interfaces/IERC165.sol";

import "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract TransferLocks is ERC20Upgradeable, ITransferLocks, IERC165 {
    /// @inheritdoc ITransferLocks
    function addTransferLock(uint256 amount, uint256 deadline) public {
        require(deadline > block.timestamp, "TransferLock: deadline must be in the future");
        require(
            amount <= getAvailableBalanceAt(msg.sender, deadline),
            "TransferLock: amount cannot exceed available balance"
        );
        TransferLocksStorage.addTransferLock(msg.sender, amount, deadline);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotal(address account) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, block.timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotalAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getAvailableBalanceAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        uint256 totalLocked = TransferLocksStorage.getTotalLockedAt(account, timestamp);
        return balanceOf(account) - totalLocked;
    }

    /// @dev Override ERC20Upgradeable._beforeTokenTransfer to check for transfer locks.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        uint256 lockedAmount = getTransferLockTotalAt(from, block.timestamp);
        if (lockedAmount > 0 && balanceOf(from) >= amount) {
            require(balanceOf(from) - amount >= lockedAmount, "TransferLock: this exceeds your unlocked balance");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(ITransferLocks).interfaceId;
    }
}
