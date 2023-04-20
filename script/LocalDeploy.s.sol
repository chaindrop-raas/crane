// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Script} from "@std/Script.sol";
import {console2} from "@std/console2.sol";

import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {OrigamiMembershipToken} from "src/OrigamiMembershipToken.sol";
import {GovernorDiamondInit} from "src/utils/GovernorDiamondInit.sol";

import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";
import {GovernorCoreFacet} from "src/governor/GovernorCoreFacet.sol";
import {GovernorSettingsFacet} from "src/governor/GovernorSettingsFacet.sol";
import {GovernorTimelockControlFacet} from "src/governor/GovernorTimelockControlFacet.sol";

import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {Diamond} from "@diamond/Diamond.sol";
import {OrigamiTimelockController} from "src/OrigamiTimelockController.sol";

// solhint-disable no-console
contract LocalDeploy is Script {
    mapping(string => address) public implementationAddresses;
    mapping(string => address) public facetAddresses;
    mapping(string => address) public proxyAddresses;
    mapping(string => address) public governorAddresses;

    function run(address contractAdmin) public {
        vm.startBroadcast();
        deployImplementations();
        deployGovernorFacets();
        deployProxies();
        deployTokens(contractAdmin);
        deployGovernor(contractAdmin);
        vm.stopBroadcast();
    }

    function deployImplementations() public {
        OrigamiGovernanceToken govToken = new OrigamiGovernanceToken();
        console2.log("OrigamiGovernanceToken (impl): ", address(govToken));
        implementationAddresses["OrigamiGovernanceToken"] = address(govToken);

        OrigamiMembershipToken memToken = new OrigamiMembershipToken();
        console2.log("OrigamiMembershipToken (impl): ", address(memToken));
        implementationAddresses["OrigamiMembershipToken"] = address(memToken);

        GovernorDiamondInit diamondInit = new GovernorDiamondInit();
        console2.log("GovernorDiamondInit: ", address(diamondInit));
        implementationAddresses["GovernorDiamondInit"] = address(diamondInit);
    }

    function deployGovernorFacets() public {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console2.log("DiamondCutFacet: ", address(diamondCutFacet));
        facetAddresses["DiamondCutFacet"] = address(diamondCutFacet);

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console2.log("DiamondLoupeFacet: ", address(diamondLoupeFacet));
        facetAddresses["DiamondLoupeFacet"] = address(diamondLoupeFacet);

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        console2.log("OwnershipFacet: ", address(ownershipFacet));
        facetAddresses["OwnershipFacet"] = address(ownershipFacet);

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();
        console2.log("GovernorCoreFacet: ", address(governorCoreFacet));
        facetAddresses["GovernorCoreFacet"] = address(governorCoreFacet);

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        console2.log("GovernorSettingsFacet: ", address(governorSettingsFacet));
        facetAddresses["GovernorSettingsFacet"] = address(governorSettingsFacet);

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        console2.log("GovernorTimelockControlFacet: ", address(governorTimelockControlFacet));
        facetAddresses["GovernorTimelockControlFacet"] = address(governorTimelockControlFacet);
    }

    function deployProxies() public {
        ProxyAdmin admin = new ProxyAdmin();
        console2.log("ProxyAdmin: ", address(admin));
        proxyAddresses["ProxyAdmin"] = address(admin);

        TransparentUpgradeableProxy govTokenproxy = new TransparentUpgradeableProxy(
                implementationAddresses["OrigamiGovernanceToken"],
                address(admin),
                ""
            );
        console2.log("GovTokenProxy (transparent upgradable): ", address(govTokenproxy));
        proxyAddresses["GovTokenProxy"] = address(govTokenproxy);

        TransparentUpgradeableProxy memTokenproxy = new TransparentUpgradeableProxy(
                implementationAddresses["OrigamiMembershipToken"],
                address(admin),
                ""
            );
        console2.log("MemTokenProxy (transparent upgradable): ", address(memTokenproxy));
        proxyAddresses["MemTokenProxy"] = address(memTokenproxy);
    }

    function deployTokens(address contractAdmin) public {
        OrigamiMembershipToken memToken = OrigamiMembershipToken(proxyAddresses["MemTokenProxy"]);
        memToken.initialize(contractAdmin, "OrigamiTeamToken", "MGAMI", "localhost");
        console2.log("OrigamiMembershipToken: ", address(memToken));
        console2.log("Name: ", memToken.name());
        console2.log("Symbol: ", memToken.symbol());

        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(proxyAddresses["GovTokenProxy"]);
        govToken.initialize(contractAdmin, "OrigamiGovToken", "GAMI", 1000000000000000000000000000);
        console2.log("OrigamiGovernanceToken: ", address(govToken));
        console2.log("Name: ", govToken.name());
        console2.log("Symbol: ", govToken.symbol());
        console2.log("Supply Cap: ", govToken.cap());
    }

    function deployGovernor(address contractAdmin) public {
        Diamond governor = new Diamond(
            contractAdmin,
            facetAddresses["DiamondCutFacet"]
        );
        console2.log("GovernorDiamond: ", address(governor));
        governorAddresses["GovernorDiamond"] = address(governor);

        address[] memory operators = new address[](1);
        operators[0] = address(governor);

        OrigamiTimelockController timelock = new OrigamiTimelockController(
            300,
            operators,
            operators
        );
        console2.log("TimelockController: ", address(timelock));
        console2.log("Time delay: 300");
        governorAddresses["TimelockController"] = address(timelock);
    }
}
