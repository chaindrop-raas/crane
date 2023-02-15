// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiMembershipToken.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";

import {CREATE3, CREATE3Factory} from "@create3/Create3Factory.sol";

contract DeterministicDeploy is Script {
    function transparentProxyByteCode(address implementation, address proxyAdmin) public pure returns (bytes memory) {
        bytes memory contractBytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory encodedInitialization = abi.encode(implementation, proxyAdmin, "");
        return abi.encodePacked(contractBytecode, encodedInitialization);
    }

    function getDeterministicAddress(address create3Factory, address deployer, string calldata salt)
        public
        view
        returns (address)
    {
        return CREATE3Factory(create3Factory).getDeployed(deployer, bytes32(bytes(salt)));
    }

    function deployCreate3Factory() public {
        vm.startBroadcast();
        CREATE3Factory c3 = new CREATE3Factory();
        console2.log("CREATE3Factory deployed at", address(c3));
        vm.stopBroadcast();
    }

    function deployGovernanceTokenProxy(
        address create3Factory,
        string calldata orgSnowflake,
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        uint256 supplyCap
    ) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = transparentProxyByteCode(implementation, proxyAdmin);
        string memory salt = string.concat("governance-token-", orgSnowflake);

        vm.startBroadcast();
        address govTokenProxy = c3.deploy(bytes32(bytes(salt)), bytecode);
        OrigamiGovernanceToken token = OrigamiGovernanceToken(govTokenProxy);
        token.initialize(contractAdmin, name, symbol, supplyCap);
        vm.stopBroadcast();
    }

    function deployMembershipTokenProxy(
        address create3Factory,
        string calldata orgSnowflake,
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        string calldata baseUri
    ) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = transparentProxyByteCode(implementation, proxyAdmin);
        string memory salt = string.concat("membership-token-", orgSnowflake);

        vm.startBroadcast();
        address memTokenProxy = c3.deploy(bytes32(bytes(salt)), bytecode);
        OrigamiMembershipToken token = OrigamiMembershipToken(memTokenProxy);
        token.initialize(contractAdmin, name, symbol, baseUri);
        vm.stopBroadcast();
    }
}
