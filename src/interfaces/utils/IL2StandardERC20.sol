// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@diamond/interfaces/IERC165.sol";

interface ILegacyMintableERC20 is IERC165 {
    function l1Token() external returns (address);
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}

interface IL2StandardERC20 is IERC165, ILegacyMintableERC20 {
    /// @dev emitted when the L1 token address is updated
    event L1TokenUpdated(address indexed oldL1Token, address indexed newL1Token);
    /// @dev emitted when the L2 bridge address is updated
    event L2BridgeUpdated(address indexed oldL2Bridge, address indexed newL2Bridge);
    /// @dev emitted when tokens are minted
    event Mint(address indexed _account, uint256 _amount);
    /// @dev emitted when tokens are burned
    event Burn(address indexed _account, uint256 _amount);

    function l1Token() external returns (address);
    function l2Bridge() external returns (address);

    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}
