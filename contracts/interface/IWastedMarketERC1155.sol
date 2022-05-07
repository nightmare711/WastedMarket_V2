//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWastedMarketERC1155 {
    event Listing(
        uint256 wastedId,
        uint256 price,
        uint256 amount,
        address seller
    );
    event Delist(uint256 wastedId, address seller);

    event Bought(
        uint256 wastedId,
        address buyer,
        address seller,
        uint256 amount,
        uint256 price
    );

    event Offered(
        uint256 wastedId,
        address buyer,
        uint256 amount,
        uint256 price
    );

    event OfferCanceled(uint256 wastedId, address caller);

    struct BuyInfo {
        uint256 amount;
        uint256 price;
    }

    function listing(
        uint256 wastedId,
        uint256 price,
        uint256 amount,
        address seller
    ) external returns (uint256);

    function delist(uint256 wastedId, address caller) external;

    function buy(
        uint256 wastedId,
        address seller,
        uint256 expectedPrice,
        address buyer
    ) external returns (uint256);

    function offer(
        uint256 wastedId,
        uint256 offerPrice,
        address caller,
        uint256 amount
    ) external returns (uint256);

    function acceptOffer(
        uint256 wastedId,
        address buyer,
        uint256 expectedPrice,
        address seller
    ) external returns (uint256);

    function abortOffer(uint256 wastedId, address caller) external;

    function setMarketFee(uint256 _marketFee) external;

    function switchPause(bool isPaused) external;

    function setReceiverFee(address _receiverFee) external;
}
