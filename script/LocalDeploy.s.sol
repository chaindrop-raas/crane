// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Script} from "@std/Script.sol";
import {console2} from "@std/console2.sol";
import {Test} from "@std/Test.sol";
import {VmSafe} from "@std/Vm.sol";
import {IAccessControl} from "src/interfaces/IAccessControl.sol";

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
    bytes32 internal constant REVOKER_ROLE = 0xce3f34913921da558f105cefb578d87278debbbd073a8d552b5de0d168deee30;
    bytes32 internal constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    mapping(string => address) public addresses;

    string[10] public reusableContracts = [
        "OrigamiGovernanceToken",
        "OrigamiMembershipToken",
        "GovernorDiamondInit",
        "DiamondCutFacet",
        "DiamondLoupeFacet",
        "OwnershipFacet",
        "GovernorCoreFacet",
        "GovernorSettingsFacet",
        "GovernorTimelockControlFacet",
        "ProxyAdmin"
    ];

    function run(address contractAdmin) public {
        vm.startBroadcast();
        deserializeReusableContractAddresses();
        deployImplementations();
        deployGovernorFacets();
        deployProxies();
        deployTokens(contractAdmin);
        deployGovernor(contractAdmin);
        serializeReusableContractAddresses();
        vm.stopBroadcast();
    }

    // has to be a fn, since project root isn't available at compile time
    function artifactPath() public view returns (string memory) {
        return string.concat(vm.projectRoot(), "/artifacts/data.json");
    }

    function serializeReusableContractAddresses() public {
        string memory json = "addresses";
        for (uint256 i = 0; i < reusableContracts.length; i++) {
            vm.serializeAddress(json, reusableContracts[i], addresses[reusableContracts[i]]);
        }

        string memory meta = vm.serializeUint("metadata", "timestamp", block.timestamp);
        string memory finalJson = vm.serializeString(json, "metadata", meta);
        vm.writeJson(finalJson, artifactPath());
    }

    function deserializeReusableContractAddresses() public {
        string memory path = artifactPath();
        VmSafe.DirEntry[] memory entries = vm.readDir("artifacts");
        bool fileExists;
        for (uint256 i = 0; i < entries.length; i++) {
            if (keccak256(abi.encodePacked(entries[i].path)) == keccak256(abi.encodePacked(path))) {
                fileExists = true;
                break;
            }
        }
        if (fileExists) {
            string memory file = vm.readFile(path);
            for (uint256 i = 0; i < reusableContracts.length; i++) {
                addresses[reusableContracts[i]] = vm.parseJsonAddress(file, string.concat(".", reusableContracts[i]));
            }
        }
    }

    function isUndeployed(string memory contractName) public view returns (bool) {
        address contractAddr = addresses[contractName];
        return contractAddr == address(0) || address(contractAddr).codehash == 0x0;
    }

    function deployImplementations() public {
        if (isUndeployed("OrigamiGovernanceToken")) {
            OrigamiGovernanceToken govToken = new OrigamiGovernanceToken();
            addresses["OrigamiGovernanceToken"] = address(govToken);
        }

        if (isUndeployed("OrigamiMembershipToken")) {
            OrigamiMembershipToken memToken = new OrigamiMembershipToken();
            addresses["OrigamiMembershipToken"] = address(memToken);
        }

        if (isUndeployed("GovernorDiamondInit")) {
            GovernorDiamondInit diamondInit = new GovernorDiamondInit();
            addresses["GovernorDiamondInit"] = address(diamondInit);
        }
    }

    function deployGovernorFacets() public {
        if (isUndeployed("DiamondCutFacet")) {
            DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
            addresses["DiamondCutFacet"] = address(diamondCutFacet);
        }

        if (isUndeployed("DiamondLoupeFacet")) {
            DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
            addresses["DiamondLoupeFacet"] = address(diamondLoupeFacet);
        }

        if (isUndeployed("OwnershipFacet")) {
            OwnershipFacet ownershipFacet = new OwnershipFacet();
            addresses["OwnershipFacet"] = address(ownershipFacet);
        }

        if (isUndeployed("GovernorCoreFacet")) {
            GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();
            addresses["GovernorCoreFacet"] = address(governorCoreFacet);
        }

        if (isUndeployed("GovernorSettingsFacet")) {
            GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
            addresses["GovernorSettingsFacet"] = address(governorSettingsFacet);
        }

        if (isUndeployed("GovernorTimelockControlFacet")) {
            GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
            addresses["GovernorTimelockControlFacet"] = address(governorTimelockControlFacet);
        }
    }

    function deployProxies() public {
        ProxyAdmin admin;

        if (isUndeployed("ProxyAdmin")) {
            admin = new ProxyAdmin();
            addresses["ProxyAdmin"] = address(admin);
        } else {
            admin = ProxyAdmin(addresses["ProxyAdmin"]);
        }

        TransparentUpgradeableProxy govTokenproxy = new TransparentUpgradeableProxy(
                addresses["OrigamiGovernanceToken"],
                address(admin),
                ""
            );
        console2.log("GovTokenProxy (transparent upgradable): ", address(govTokenproxy));
        addresses["GovTokenProxy"] = address(govTokenproxy);

        TransparentUpgradeableProxy memTokenproxy = new TransparentUpgradeableProxy(
                addresses["OrigamiMembershipToken"],
                address(admin),
                ""
            );
        console2.log("MemTokenProxy (transparent upgradable): ", address(memTokenproxy));
        addresses["MemTokenProxy"] = address(memTokenproxy);
    }

    function deployTokens(address contractAdmin) public {
        OrigamiMembershipToken memToken = OrigamiMembershipToken(addresses["MemTokenProxy"]);
        memToken.initialize(contractAdmin, "OrigamiTeamToken", "MGAMI", "localhost");
        console2.log("OrigamiMembershipToken: ", address(memToken));
        console2.log("Name: ", memToken.name());
        console2.log("Symbol: ", memToken.symbol());

        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(addresses["GovTokenProxy"]);
        govToken.initialize(contractAdmin, "OrigamiGovToken", "GAMI", 1000000000000000000000000000);
        console2.log("OrigamiGovernanceToken: ", address(govToken));
        console2.log("Name: ", govToken.name());
        console2.log("Symbol: ", govToken.symbol());
        console2.log("Supply Cap: ", govToken.cap());
    }

    function deployGovernor(address contractAdmin) public {
        Diamond governor = new Diamond(
            contractAdmin,
            addresses["DiamondCutFacet"]
        );
        console2.log("GovernorDiamond: ", address(governor));
        addresses["GovernorDiamond"] = address(governor);

        address[] memory operators = new address[](1);
        operators[0] = address(governor);

        OrigamiTimelockController timelock = new OrigamiTimelockController(
            300,
            operators,
            operators
        );
        console2.log("TimelockController: ", address(timelock));
        console2.log("Time delay: 300");
        addresses["TimelockController"] = address(timelock);
    }

    function relayWalletGrantPermissionAndFund(address tokenAddr, string calldata mnemonic, uint32 walletCount)
        public
    {
        vm.startBroadcast();
        IAccessControl accessControl = IAccessControl(tokenAddr);
        for (uint32 i = 0; i < walletCount; i++) {
            uint256 privateKey = vm.deriveKey(mnemonic, i);
            address wallet = vm.addr(privateKey);
            accessControl.grantRole(REVOKER_ROLE, wallet);
            accessControl.grantRole(MINTER_ROLE, wallet);
            (bool success,) = wallet.call{value: 10000000000000000000}("");
            require(success, "ETH transfer did not work");
            console2.log("Fund wallet:", wallet);
            console2.log("Wallet balance:", wallet.balance);
        }
        vm.stopBroadcast();
    }
}
