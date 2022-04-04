//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./utils/AcceptedTokenUpgradeable.sol";
import "./interface/IWastedWarrior.sol";
import "./utils/TokenWithdrawable.sol";

contract WastedMarket is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    AcceptedTokenUpgradeable,
    IERC721ReceiverUpgradeable,
    TokenWithdrawable
{
    using SafeMathUpgradeable for uint256;

    modifier onlyWastedOwner(uint256 warriorId, address caller) {
        ownerOf[warriorId] = caller;
        _;
    }

    event WastedOfferCanceled(uint256 indexed warriorId, address buyer);
    event WastedListed(uint256 warriorId, uint256 price, address seller);
    event WastedDelisted(uint256 indexed warriorId);
    event WastedBought(
        uint256 indexed warriorId,
        address buyer,
        address seller,
        uint256 price
    );
    event WastedOffered(
        uint256 indexed warriorId,
        address buyer,
        uint256 price
    );

    IWastedWarrior public wastedContract;

    bool public paused;
    uint256 public marketFeeInPercent;
    uint256 public floorprice;
    uint256 public PERCENT;
    mapping(uint256 => uint256) public wastedsOnSale;
    mapping(uint256 => mapping(address => uint256)) public wastedsOffers;
    mapping(uint256 => address) public ownerOf;

    function initialize(
        IWastedWarrior _wastedContract,
        IERC20Upgradeable _acceptedToken
    ) public initializer {
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        TokenWithdrawable.initialize();
        AcceptedTokenUpgradeable.initialize(_acceptedToken);
        wastedContract = _wastedContract;
        PERCENT = 100;
        marketFeeInPercent = 4;
    }

    function setWastedContract(IWastedWarrior _wastedContract)
        external
        onlyOwner
    {
        wastedContract = _wastedContract;
    }

    function setMarketFeeInPercent(uint256 _marketFeeInPercent)
        external
        onlyOwner
    {
        marketFeeInPercent = _marketFeeInPercent;
    }

    function setFloorPrice(uint256 _floorprice) external onlyOwner {
        floorprice = _floorprice;
    }

    function listing(uint256 warriorId, uint256 price) external {
        uint256 oldListing = wastedContract.getWarriorListing(warriorId);
        require(!paused, "WM: paused");
        require(oldListing == 0, "WM: delist old contract");
        require(price > 0, "WM: invalid price");
        require(price >= floorprice, "WM: price must greater than floorprice");

        if (wastedsOnSale[warriorId] == 0) {
            wastedContract.safeTransferFrom(
                msg.sender,
                address(this),
                warriorId
            );
            ownerOf[warriorId] = msg.sender;
        } else {
            require(ownerOf[warriorId] == msg.sender, "WM: invalid owner");
        }

        wastedsOnSale[warriorId] = price;

        emit WastedListed(warriorId, price, msg.sender);
    }

    function delist(uint256 warriorId)
        external
        onlyWastedOwner(warriorId, msg.sender)
    {
        require(!paused, "WM: paused");
        require(wastedsOnSale[warriorId] > 0, "WM: delist first");

        wastedsOnSale[warriorId] = 0;
        wastedContract.transferFrom(address(this), msg.sender, warriorId);

        emit WastedDelisted(warriorId);
    }

    function buy(uint256 warriorId, uint256 expectedPrice)
        external
        nonReentrant
    {
        uint256 price = wastedsOnSale[warriorId];
        address seller = ownerOf[warriorId];
        address buyer = msg.sender;

        require(!paused, "WW: paused");
        require(buyer != seller);
        require(price == expectedPrice);
        require(price > 0, "WW: not sale");

        collectToken(buyer, address(this), price);

        _makeTransaction(warriorId, buyer, seller, price);

        emit WastedBought(warriorId, buyer, seller, price);
    }

    function offer(uint256 warriorId, uint256 offerPrice)
        external
        nonReentrant
    {
        require(!paused);
        address buyer = msg.sender;
        uint256 currentOffer = wastedsOffers[warriorId][buyer];
        bool needRefund = offerPrice < currentOffer;
        uint256 requiredValue = needRefund ? 0 : offerPrice - currentOffer;

        require(buyer != ownerOf[warriorId]);
        require(offerPrice != currentOffer);

        collectToken(buyer, address(this), requiredValue);
        wastedsOffers[warriorId][buyer] = offerPrice;

        if (needRefund) {
            uint256 returnedValue = currentOffer - offerPrice;

            refundToken(buyer, returnedValue);
            // (bool success, ) = buyer.call{value: returnedValue}("");
            // require(success);
        }

        emit WastedOffered(warriorId, buyer, offerPrice);
    }

    function acceptOffer(
        uint256 warriorId,
        address buyer,
        uint256 expectedPrice
    ) external nonReentrant onlyWastedOwner(warriorId, msg.sender) {
        require(!paused);
        uint256 offeredPrice = wastedsOffers[warriorId][buyer];
        address seller = msg.sender;
        require(expectedPrice == offeredPrice);
        require(buyer != seller);

        wastedsOffers[warriorId][buyer] = 0;

        _makeTransaction(warriorId, buyer, seller, offeredPrice);

        emit WastedBought(warriorId, buyer, seller, offeredPrice);
    }

    function abortOffer(uint256 warriorId) external nonReentrant {
        address caller = msg.sender;
        uint256 offerPrice = wastedsOffers[warriorId][caller];

        require(offerPrice > 0);

        wastedsOffers[warriorId][caller] = 0;

        refundToken(caller, offerPrice);
        // (bool success, ) = caller.call{value: offerPrice}("");
        // require(success);

        emit WastedOfferCanceled(warriorId, caller);
    }

    function _makeTransaction(
        uint256 warriorId,
        address buyer,
        address seller,
        uint256 price
    ) private {
        uint256 marketFee = (price * marketFeeInPercent) / PERCENT;

        wastedsOnSale[warriorId] = 0;

        refundToken(seller, price.sub(marketFee));
        // (bool isTransferToSeller, ) = seller.call{value: price - marketFee}("");
        // require(isTransferToSeller);

        if (marketFee > 0) {
            refundToken(owner(), marketFee);
        }
        // (bool isTransferToTreasury, ) = owner().call{value: marketFee}("");
        // require(isTransferToTreasury);

        wastedContract.transferFrom(address(this), buyer, warriorId);
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
