// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "src/OrigamiTimelockController.sol";
import "src/utils/DiamondDeployHelper.sol";
import "src/utils/GovernorDiamondInit.sol";

import "@std/Script.sol";
import "@diamond/Diamond.sol";

contract DeployGovernorFacets is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console2.log("DiamondCutFacet deployed at", address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console2.log("DiamondLoupeFacet deployed at", address(diamondLoupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        console2.log("OwnershipFacet deployed at", address(ownershipFacet));

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();
        console2.log("GovernorCoreFacet deployed at", address(governorCoreFacet));

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        console2.log("GovernorSettingsFacet deployed at", address(governorSettingsFacet));

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        console2.log("GovernorTimelockControlFacet deployed at", address(governorTimelockControlFacet));

        vm.stopBroadcast();
    }
}

contract DeployGovernorDiamondInit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        GovernorDiamondInit diamondInit = new GovernorDiamondInit();
        console2.log("GovernorDiamondInit deployed at:", address(diamondInit));
        vm.stopBroadcast();
    }
}

contract DeployGovernorDiamond is Script {
    function run(address admin, address diamondCutFacet) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        Diamond governor = new Diamond(admin, diamondCutFacet);
        console2.log("GovernorDiamond deployed at:", address(governor));
        vm.stopBroadcast();
    }
}

contract DeployGovernorTimelockController is Script {
    function run(address governor, uint256 timelockDelay) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address[] memory operators = new address[](1);
        operators[0] = governor;

        vm.startBroadcast(deployerPrivateKey);
        OrigamiTimelockController timelock = new OrigamiTimelockController(timelockDelay, operators, operators);
        console2.log("TimelockController deployed at:", address(timelock));
        vm.stopBroadcast();
    }
}

contract GovernorInstance is Script {
    struct GovernorConfig {
        string name;
        address diamondLoupeFacet;
        address ownershipFacet;
        address governorCoreFacet;
        address governorSettingsFacet;
        address governorTimelockControlFacet;
        address membershipToken;
        address proposalToken;
        address proposalThresholdToken;
        uint256 proposalThreshold;
        uint256 votingPeriod;
        uint256 votingDelay;
        uint256 quorumPercentage;
    }

    function parseGovernorConfig(string calldata relativePath) public returns (GovernorConfig memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/", relativePath);
        string memory json = vm.readFile(path);
        return abi.decode(vm.parseJson(json), (GovernorConfig));
    }

    function facetCuts(GovernorConfig memory config) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        cuts[0] = DiamondDeployHelper.diamondLoupeFacetCut(config.diamondLoupeFacet);
        cuts[1] = DiamondDeployHelper.ownershipFacetCut(config.ownershipFacet);
        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(GovernorCoreFacet(config.governorCoreFacet));
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(GovernorSettingsFacet(config.governorSettingsFacet));
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(
            GovernorTimelockControlFacet(config.governorTimelockControlFacet)
        );

        return cuts;
    }

    function encodeConfig(address admin, address timelock, GovernorConfig memory config)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "init(string,address,address,address,address,address,uint64,uint64,uint128,uint256)",
            config.name,
            admin,
            timelock,
            config.membershipToken,
            config.proposalToken,
            config.proposalThresholdToken,
            config.votingDelay,
            config.votingPeriod,
            config.quorumPercentage,
            config.proposalThreshold
        );
    }

    function configure(
        address governorDiamondInit,
        address governorDiamond,
        address timelock,
        string calldata relativeConfigPath
    ) external {
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(adminPrivateKey);

        GovernorConfig memory config = parseGovernorConfig(relativeConfigPath);

        vm.startBroadcast(adminPrivateKey);
        IDiamondCut.FacetCut[] memory cuts = facetCuts(config);
        DiamondCutFacet(governorDiamond).diamondCut(cuts, governorDiamondInit, encodeConfig(admin, timelock, config));
        vm.stopBroadcast();
    }
}
