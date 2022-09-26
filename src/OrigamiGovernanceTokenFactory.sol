// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/proxy/ClonesUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./OrigamiGovernanceToken.sol";

/// @title Origami Governance Token Factory
/// @author Stephen Caudill
/// @notice This contract is used to create clones (lower cost deployments) of the OrigamiGovernanceToken contract and deploy upgradeable proxies to them, while still allowing full configuration of the instances.
/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiGovernanceTokenFactory is
    Initializable,
    AccessControlUpgradeable
{
    /// @notice The list of proxies created by this contract.
    address[] public proxiedContracts;
    /// @dev The address of the OrigamiGovernanceToken implementation contract used for the clones.
    address private tokenImplementation;

    /// @notice The event emitted when a new OrigamiGovernanceToken is created.
    event OrigamiGovernanceTokenCreated(
        address indexed caller,
        address indexed proxy
    );

    /// @notice the constructor is not used since the contract is upgradeable except to disable initializers in the implementations that are deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev this function is used to initialize the contract. It is called during contract deployment.
    /// @notice this function is not intended to be called by external users.
    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        tokenImplementation = address(new OrigamiGovernanceToken());
    }

    /// @dev this is the programatic interface for creating a new OrigamiGovernanceToken.
    /// @notice This is the interface for creating new proxied clones of the OrigamiGovernanceToken. This function is only invokable by the contract admin.
    /// @param _admin the address of the contract admin. This address receives all roles by default and should be used to delegate them to DAO committees and/or permanent members.
    /// @param _name the name of the token. Typically this is the name of the DAO.
    /// @param _symbol the symbol of the token. Typically this is a short abbreviation of the DAO's name.
    /// @param _supplyCap cap on the total supply mintable by this contract.
    /// @return the address of the newly deployed OrigamiGovernanceToken.
    function createOrigamiGovernanceToken(
        address _admin,
        string memory _name,
        string memory _symbol,
        uint256 _supplyCap
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        address clone = ClonesUpgradeable.clone(tokenImplementation);
        bytes memory data = abi.encodeWithSelector(
            OrigamiGovernanceToken(clone).initialize.selector,
            _admin,
            _name,
            _symbol,
            _supplyCap
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            clone,
            _msgSender(),
            data
        );
        proxiedContracts.push(address(proxy));
        emit OrigamiGovernanceTokenCreated(_msgSender(), address(proxy));
        return address(proxy);
    }

    /// @dev this is the programatic interface for getting the address of a proxy contract.
    /// @notice Retrieve a proxy contract address by index.
    /// @param index The zero-based index of the proxy contract to retrieve.
    /// @return the address of the proxy contract at the given index.
    function getProxyContractAddress(uint256 index)
        public
        view
        returns (address payable)
    {
        require(
            index < proxiedContracts.length,
            "Proxy address index out of bounds"
        );
        return payable(proxiedContracts[index]);
    }

    /// @notice Set the address for a new implementation contract. This function is only invokable by the contract admin.
    /// @param _tokenImplementation the address of the new implementation contract.
    function setTokenImplementation(address _tokenImplementation)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenImplementation = _tokenImplementation;
    }
}
