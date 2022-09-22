// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@oz-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@oz-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@oz-upgradeable/security/PausableUpgradeable.sol";
import "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import "@oz-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";
import "@oz-upgradeable/utils/CountersUpgradeable.sol";

/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiMembershipTokenBeforeInitialAuditFeedback is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    CountersUpgradeable.Counter private _tokenIdCounter;
    mapping(uint256 => uint256) tokenIdToBlockTimestamp;

    string public _metadataBaseURI;
    bool private _transferEnabled;

    event Mint(address indexed _to, uint256 indexed _tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        string memory _name,
        string memory _symbol,
        string memory baseURI_
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        // Temporarily grant admin to caller so it can grant the following roles.
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // grant all roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(REVOKER_ROLE, _admin);

        // revoke admin grant for caller
        _revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _metadataBaseURI = baseURI_;
        _transferEnabled = false;
    }

    function _baseURI() internal view override returns (string memory) {
        return _metadataBaseURI;
    }

    function setBaseURI(string memory baseURI_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _metadataBaseURI = baseURI_;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        tokenIdToBlockTimestamp[tokenId] = block.timestamp;
        emit Mint(to, tokenId);
    }

    function revoke(address from) public onlyRole(REVOKER_ROLE) {
        require(balanceOf(from) == 1, "Revoke: cannot revoke");
        _burn(tokenOfOwnerByIndex(from, 0));
    }

    function transferrable() public view returns (bool) {
        return _transferEnabled;
    }

    function enableTransfer() public onlyRole(DEFAULT_ADMIN_ROLE) whenNontransferrable {
        _transferEnabled = true;
    }

    function disableTransfer() public onlyRole(DEFAULT_ADMIN_ROLE) whenTransferrable {
        _transferEnabled = false;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override whenTransferrable {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override whenTransferrable {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override whenTransferrable {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) limitBalance(to) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        require(tokenId > 0, "Invalid token ID");
        require(tokenId <= _tokenIdCounter.current(), "Invalid token ID");
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    modifier limitBalance(address recipient) {
        // allow unlimited transfers to the burn address
        require(recipient == address(0) || balanceOf(recipient) == 0, "Holders may only have one token");
        _;
    }

    modifier whenNontransferrable() {
        require(!transferrable(), "Transferrable: transfers are enabled");
        _;
    }

    modifier whenTransferrable() {
        require(transferrable(), "Transferrable: transfers are disabled");
        _;
    }
}
