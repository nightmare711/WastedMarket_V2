//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/AcceptedToken.sol";
import "./interface/IWastedWarrior.sol";

contract WastedMarket is
    ReentrancyGuard,
    Ownable,
    AcceptedToken,
    IERC721Receiver
{
    using SafeMath for uint256;

    modifier onlyWastedOwner(uint256 wastedId, address caller) {
        ownerOf[wastedId] = caller;
        _;
    }

    event WastedOfferCanceled(uint256 indexed wastedId, address buyer);
    event WastedListed(uint256 wastedId, uint256 price, address seller);
    event WastedDelisted(uint256 indexed tunvierId);
    event WastedBought(
        uint256 indexed tunvierId,
        address buyer,
        address seller,
        uint256 price
    );
    event WastedOffered(
        uint256 indexed tunvierId,
        address buyer,
        uint256 price
    );

    IWastedWarrior public wastedContract;

    bool public paused;
    uint256 marketFeeInPercent;
    uint256 constant PERCENT = 100;
    mapping(uint256 => uint256) public wastedsOnSale;
    mapping(uint256 => mapping(address => uint256)) public wastedsOffers;
    mapping(uint256 => address) public ownerOf;

    constructor(IWastedWarrior _wastedContract, IERC20 _acceptedToken)
        AcceptedToken(_acceptedToken)
    {
        wastedContract = _wastedContract;
    }

    function listing(uint256 wastedId, uint256 price) external {
        require(!paused);
        require(price > 0);

        wastedContract.safeTransferFrom(msg.sender, address(this), wastedId);

        wastedsOnSale[wastedId] = price;
        ownerOf[wastedId] = msg.sender;

        emit WastedListed(wastedId, price, msg.sender);
    }

    function delist(uint256 wastedId)
        external
        onlyWastedOwner(wastedId, msg.sender)
    {
        require(!paused, "WW: paused");
        require(wastedsOnSale[wastedId] > 0);

        wastedsOnSale[wastedId] = 0;
        wastedContract.transferFrom(address(this), msg.sender, wastedId);

        emit WastedDelisted(wastedId);
    }

    function buy(
        uint256 wastedId,
        uint256 expectedPrice,
        address buyer
    ) external payable nonReentrant {
        uint256 price = wastedsOnSale[wastedId];
        address seller = ownerOf[wastedId];

        require(!paused, "WW: paused");
        require(buyer != seller);
        require(price == expectedPrice);
        require(price > 0, "WW: not sale");

        _makeTransaction(wastedId, buyer, seller, price);

        emit WastedBought(wastedId, buyer, seller, price);
    }

    function offer(uint256 wastedId, uint256 offerPrice)
        external
        payable
        nonReentrant
    {
        require(!paused);
        address buyer = msg.sender;
        uint256 currentOffer = wastedsOffers[wastedId][buyer];
        bool needRefund = offerPrice < currentOffer;
        uint256 requiredValue = needRefund ? 0 : offerPrice - currentOffer;

        require(buyer != ownerOf[wastedId]);
        require(offerPrice != currentOffer);
        require(msg.value == requiredValue);

        wastedsOffers[wastedId][buyer] = offerPrice;

        if (needRefund) {
            uint256 returnedValue = currentOffer - offerPrice;

            collectToken(address(this), buyer, returnedValue);
            // (bool success, ) = buyer.call{value: returnedValue}("");
            // require(success);
        }

        emit WastedOffered(wastedId, buyer, offerPrice);
    }

    function acceptOffer(
        uint256 wastedId,
        address buyer,
        uint256 expectedPrice
    ) external nonReentrant onlyWastedOwner(wastedId, msg.sender) {
        require(!paused);
        uint256 offeredPrice = wastedsOffers[wastedId][buyer];
        address seller = msg.sender;
        require(expectedPrice == offeredPrice);
        require(buyer != seller);

        wastedsOffers[wastedId][buyer] = 0;

        _makeTransaction(wastedId, buyer, seller, offeredPrice);

        emit WastedBought(wastedId, buyer, seller, offeredPrice);
    }

    function abortOffer(uint256 wastedId) external nonReentrant {
        address caller = msg.sender;
        uint256 offerPrice = wastedsOffers[wastedId][caller];

        require(offerPrice > 0);

        wastedsOffers[wastedId][caller] = 0;

        (bool success, ) = caller.call{value: offerPrice}("");
        require(success);

        emit WastedOfferCanceled(wastedId, caller);
    }

    function _makeTransaction(
        uint256 wastedId,
        address buyer,
        address seller,
        uint256 price
    ) private {
        uint256 marketFee = (price * marketFeeInPercent) / PERCENT;

        wastedsOnSale[wastedId] = 0;

        collectToken(buyer, seller, price - marketFee);
        // (bool isTransferToSeller, ) = seller.call{value: price - marketFee}("");
        // require(isTransferToSeller);

        collectToken(buyer, owner(), marketFee);
        // (bool isTransferToTreasury, ) = owner().call{value: marketFee}("");
        // require(isTransferToTreasury);

        wastedContract.transferFrom(address(this), buyer, wastedId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
