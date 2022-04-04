//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AcceptedTokenUpgradeable is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Token to be used in the ecosystem.
    IERC20Upgradeable public acceptedToken;

    function initialize(IERC20Upgradeable tokenAddress) public initializer {
        OwnableUpgradeable.__Ownable_init();
        acceptedToken = tokenAddress;
    }

    modifier collectTokenAsFee(uint256 amount, address destAddr) {
        require(
            acceptedToken.balanceOf(msg.sender) >= amount,
            "AcceptedToken: insufficient token balance"
        );
        _;
        acceptedToken.safeTransferFrom(msg.sender, destAddr, amount);
    }

    function collectToken(
        address from,
        address destAddr,
        uint256 amount
    ) public {
        acceptedToken.safeTransferFrom(from, destAddr, amount);
    }

    function refundToken(address to, uint256 amount) public {
        acceptedToken.transfer(to, amount);
    }

    /**
     * @dev Sets accepted token using in the ecosystem.
     */
    function setAcceptedTokenContract(IERC20Upgradeable tokenAddr)
        external
        onlyOwner
    {
        require(address(tokenAddr) != address(0));
        acceptedToken = tokenAddr;
    }
}
