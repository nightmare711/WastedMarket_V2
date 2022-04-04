//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWastedMarketERC1155.sol";

interface IWastedMarketRouter {
    event WastedMarketSupported(
        IWastedMarketERC1155 contractAddress,
        bool isSupport
    );
    event Listing(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        uint256 price,
        uint256 amount,
        address seller
    );

    event Delist(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        address seller
    );

    event Bought(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        address buyer,
        address seller,
        uint256 amount,
        uint256 price
    );

    event Offered(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        address buyer,
        address seller,
        uint256 price
    );

    event OfferCanceled(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        address seller,
        address caller
    );

    function isSupported(address _contract) external view returns (bool);
}
