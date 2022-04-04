//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TokenWithdrawable is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(address => bool) internal tokenBlacklist;

    event TokenWithdrawn(address token, uint256 amount, address to);

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    /**
     * @notice Blacklists a token to be withdrawn from the contract.
     */
    function blacklistToken(address _token) public onlyOwner {
        tokenBlacklist[_token] = true;
    }

    /**
     * @notice Withdraws any tokens in the contract.
     */
    function withdrawToken(
        IERC20Upgradeable token,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(
            !tokenBlacklist[address(token)],
            "TokenWithdrawable: blacklisted token"
        );
        token.safeTransfer(to, amount);
        emit TokenWithdrawn(address(token), amount, to);
    }
}
