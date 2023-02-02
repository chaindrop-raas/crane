// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/Checkpoints.sol";
import "src/interfaces/IVotes.sol";

import "@oz/utils/cryptography/ECDSA.sol";

interface IVotesToken {
    function balanceOf(address owner) external view returns (uint256 balance);
    function name() external view returns (string memory);
    function version() external pure returns (string memory);
}

abstract contract Votes is IVotes, IVotesToken {
    /// @notice the typehash for the EIP712 domain separator
    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @notice the typehash for the delegation struct
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // Implement the IVotes interface

    function getVotes(address account) public view returns (uint256) {
        return Checkpoints.getVotes(account);
    }

    function getPastVotes(address account, uint256 timestamp) public view returns (uint256) {
        return Checkpoints.getPastVotes(account, timestamp);
    }

    function getPastTotalSupply(uint256 timestamp) external view returns (uint256) {
        return Checkpoints.getPastTotalSupply(timestamp);
    }

    function delegates(address delegator) external view returns (address) {
        return Checkpoints.delegates(delegator);
    }

    function delegate(address delegatee) external {
        address oldDelegate = Checkpoints.delegates(msg.sender);
        Checkpoints.delegate(msg.sender, delegatee);
        Checkpoints.moveDelegation(oldDelegate, delegatee, IVotesToken(this).balanceOf(msg.sender));
    }

    function domainSeparatorV4() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH,
                keccak256(bytes(IVotesToken(this).name())),
                keccak256(bytes(IVotesToken(this).version())),
                block.chainid,
                address(this)
            )
        );
    }

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= expiry, "Signature expired");

        Checkpoints.DelegateStorage storage ds = Checkpoints.delegateStorage();
        address delegator = ECDSA.recover(
            ECDSA.toTypedDataHash(
                domainSeparatorV4(), keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))
            ),
            v,
            r,
            s
        );

        require(nonce == ds.nonces[delegator], "Invalid nonce");

        ds.nonces[delegator]++;
        Checkpoints.delegate(delegator, delegatee);
    }
}
