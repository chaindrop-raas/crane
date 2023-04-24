// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IGovernorProposalQuorum} from "src/interfaces/IGovernorProposalQuorum.sol";
import {IGovernorSettings} from "src/interfaces/IGovernorSettings.sol";
import {IGovernorTimelockControl} from "src/interfaces/IGovernorTimelockControl.sol";
import {AccessControlStorage} from "src/utils/AccessControlStorage.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

// EIP-2535 specifies that the `diamondCut` function takes two optional
// arguments: address _init and bytes calldata _calldata
// These arguments are used to execute an arbitrary function using delegatecall
// in order to set state variables in the diamond during deployment or an upgrade
// More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

library GDInitHelper {
    /// @dev utility function to pack quorum numerator and denominator into a single uint256
    function packQuorum(uint128 numerator, uint128 denominator) external pure returns (uint256) {
        return uint256(numerator) << 128 | uint256(denominator);
    }
}

/**
 * @title Governor Diamond Initializer
 * @author Origami
 * @notice this contract is used to initialize the Governor Diamond.
 * @dev all state that's required at initialization must be set here.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorDiamondInit {
    function init(
        string memory governorName,
        address admin,
        address payable timelock,
        address membershipToken,
        address governanceToken,
        address defaultProposalToken,
        uint64 delay,
        uint64 period,
        uint256 quorum, // bitwise packed values for quorumNumerator (u128) and quorumDenominator (u128)
        uint256 threshold,
        bool enableGovernanceToken,
        bool enableMembershipToken
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // governor diamond specific
        ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernor).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorProposalQuorum).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorSettings).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorTimelockControl).interfaceId] = true;

        // in order to facilitate role administration, we add the admin to the admin role
        // it is advised that the admin renounces this role after the diamond is deployed
        AccessControlStorage.RoleStorage storage rs = AccessControlStorage.roleStorage();
        // 0x0 is the DEFAULT_ADMIN_ROLE
        rs.roles[0x0].members[admin] = true;

        // Initialize the governor configuration. Any subsequent changes to
        // these values should go through their interfaces in the
        // GovernorStorage libary so the proper events are emitted.
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        // by default, we only configure and enable the simple counting strategy
        config.defaultCountingStrategy = 0x6c4b0e9f;
        config.countingStrategies[0x6c4b0e9f] = true;
        // set variable values
        config.name = governorName;
        config.admin = admin;
        config.timelock = timelock;
        config.membershipToken = membershipToken;
        config.governanceToken = governanceToken;
        config.defaultProposalToken = defaultProposalToken;
        config.votingDelay = delay;
        config.votingPeriod = period;
        config.quorumNumerator = uint128(quorum >> 128);
        config.quorumDenominator = uint128(quorum);
        config.proposalThreshold = threshold;
        config.proposalThresholdToken = defaultProposalToken;
        config.proposalTokens[membershipToken] = enableMembershipToken;
        config.proposalTokens[governanceToken] = enableGovernanceToken;
    }
}
