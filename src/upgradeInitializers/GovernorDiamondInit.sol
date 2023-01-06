// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/IGovernor.sol";
import "src/governor/IGovernorQuorum.sol";
import "src/governor/IGovernorTimelockControl.sol";
import "src/governor/IGovernorSettings.sol";
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

contract GovernorDiamondInit {

    function init() external {
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
    }


}
