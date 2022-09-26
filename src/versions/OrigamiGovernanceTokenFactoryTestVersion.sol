// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/proxy/ClonesUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

// This contract is test-only and will not be deployed
import "./OrigamiGovernanceTokenTestVersion.sol";

contract OrigamiGovernanceTokenFactoryTestVersion is Initializable, AccessControlUpgradeable {
    address[] public proxiedContracts;
    address private tokenImplementation;

    event OrigamiGovernanceTokenCreated(address indexed caller, address indexed proxy);

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        setTokenImplementation(address(new OrigamiGovernanceTokenTestVersion()));
    }

    function createOrigamiGovernanceToken(
        address _admin,
        string memory _name,
        string memory _symbol,
        uint256 _supplyCap
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        address clone = ClonesUpgradeable.clone(tokenImplementation);
        bytes memory data = abi.encodeWithSelector(
            OrigamiGovernanceTokenTestVersion(clone).initialize.selector,
            _admin,
            _name,
            _symbol,
            _supplyCap
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(clone, _msgSender(), data);
        proxiedContracts.push(address(proxy));
        emit OrigamiGovernanceTokenCreated(_msgSender(), address(proxy));
        return address(proxy);
    }

    function getProxyContractAddress(uint256 index) public view returns (address payable) {
        require(index < proxiedContracts.length, "Proxy address index out of bounds");
        return payable(proxiedContracts[index]);
    }

    function setTokenImplementation(address _tokenImplementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenImplementation = _tokenImplementation;
    }

    function isFromUpgrade() public pure returns (bool) {
        return true;
    }
}
