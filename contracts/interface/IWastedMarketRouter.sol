//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWastedMarketERC1155.sol";
import "./IERC1155Support.sol";

interface IWastedMarketRouter {
    event WastedMarketSupported(
        IWastedMarketERC1155 contractAddress,
        IERC1155Support _wastedExpand
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
        uint256 price,
        uint256 amount
    );

    event OfferCanceled(
        IWastedMarketERC1155 contractAddress,
        uint256 wastedId,
        address caller
    );

    function isSupported(IWastedMarketERC1155 _contract)
        external
        view
        returns (bool);
}
