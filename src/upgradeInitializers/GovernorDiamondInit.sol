// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/OrigamiTimelock.sol";
import "src/interfaces/IGovernor.sol";
import "src/interfaces/IGovernorQuorum.sol";
import "src/interfaces/IGovernorSettings.sol";
import "src/interfaces/IGovernorTimelockControl.sol";
import "src/interfaces/utils/IAccessControl.sol";
import "src/utils/AccessControlStorage.sol";
import "src/utils/GovernorStorage.sol";

import "@diamond/libraries/LibDiamond.sol";
import "@diamond/interfaces/IDiamondLoupe.sol";
import "@diamond/interfaces/IDiamondCut.sol";
import "@diamond/interfaces/IERC173.sol";
import "@diamond/interfaces/IERC165.sol";

// EIP-2535 specifies that the `diamondCut` function takes two optional
// arguments: address _init and bytes calldata _calldata
// These arguments are used to execute an arbitrary function using delegatecall
// in order to set state variables in the diamond during deployment or an upgrade
// More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

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
        uint24 delay,
        uint24 period,
        uint8 quorumPercentage,
        uint16 threshold
    ) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // governor diamond specific
        ds.supportedInterfaces[type(IGovernor).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorQuorum).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorTimelockControl).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorSettings).interfaceId] = true;
        ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;

        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();

        config.name = governorName;
        config.admin = admin;
        config.timelock = timelock;
        config.membershipToken = membershipToken;
        config.votingDelay = delay;
        config.votingPeriod = period;
        config.quorumNumerator = quorumPercentage;
        config.proposalThreshold = threshold;
        config.proposalThresholdToken = membershipToken;

        AccessControlStorage.RoleStorage storage rs = AccessControlStorage.roleStorage();
        rs.roles[0x0].members[config.admin] = true;
    }
}
