// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/interfaces/utils/IL2StandardERC20.sol";
import "@diamond/interfaces/IERC165.sol";
import "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract L2StandardERC20 is IL2StandardERC20, ERC20Upgradeable {
    bytes32 public constant L2BRIDGE_INFO_STORAGE_POSITION = keccak256("com.origami.l2bridge.info");

    struct L2BridgeInfo {
        address l1Token;
        address l2Bridge;
    }

    function l2BridgeInfoStorage() internal pure returns (L2BridgeInfo storage l2bi) {
        bytes32 position = L2BRIDGE_INFO_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            l2bi.slot := position
        }
    }

    function l1Token() public view returns (address) {
        return l2BridgeInfoStorage().l1Token;
    }

    function l2Bridge() public view returns (address) {
        return l2BridgeInfoStorage().l2Bridge;
    }

    function setL1Token(address _l1Token) public {
        l2BridgeInfoStorage().l1Token = _l1Token;
    }

    function setL2Bridge(address _l2Bridge) public {
        l2BridgeInfoStorage().l2Bridge = _l2Bridge;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(ILegacyMintableERC20).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IL2StandardERC20).interfaceId;
    }

    function mint(address account, uint256 amount) public virtual override onlyL2Bridge {
        super._mint(account, amount);
        emit Mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual override onlyL2Bridge {
        super._burn(account, amount);
        emit Burn(account, amount);
    }

    modifier onlyL2Bridge() {
        require(msg.sender == l2Bridge(), "L2StandardERC20: only L2 Bridge can mint and burn");
        _;
    }
}
