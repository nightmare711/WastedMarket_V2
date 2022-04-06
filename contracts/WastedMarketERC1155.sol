pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interface/IERC1155Support.sol";
import "./interface/IWastedMarketERC1155.sol";
import "./utils/AcceptedToken.sol";

contract WastedMarketERC1155 is
    AcceptedToken,
    ReentrancyGuard,
    AccessControl,
    ERC1155Holder,
    IWastedMarketERC1155
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    modifier onlyRouter() {
        require(hasRole(ROUTER_ROLE, msg.sender));
        _;
    }

    modifier notPaused() {
        require(!paused, "market paused");
        _;
    }

    uint256 public constant PERCENT = 100;

    IERC1155Support public wastedExpand;

    uint256 public marketFeeInPercent;
    bool public paused;
    bytes32 public ROUTER_ROLE = keccak256("ROUTER_ROLE");

    mapping(uint256 => uint256) tradeIdToTokenId;
    mapping(address => mapping(uint256 => BuyInfo)) public wastedsOnSale; //owner => tokenId => amount && price
    mapping(address => mapping(uint256 => BuyInfo)) public wastedsOffer; // caller => tokenId => amount && price

    constructor(
        IERC1155Support wastedExpand_,
        uint256 marketFeeInPercent_,
        IERC20 tokenAddress,
        address router
    ) AcceptedToken(tokenAddress) {
        marketFeeInPercent = marketFeeInPercent_;
        wastedExpand = wastedExpand_;
        _setupRole(
            DEFAULT_ADMIN_ROLE,
            0x40cfBcFfA02B1Cae039921a604dbb5566520C03f
        ); // address admin
        _setupRole(ROUTER_ROLE, router);
    }

    function setMarketFee(uint256 _marketFee) external onlyRouter {
        marketFeeInPercent = _marketFee;
    }

    function switchPause(bool isPaused) external onlyRouter {
        paused = isPaused;
    }

    function listing(
        uint256 wastedId,
        uint256 price,
        uint256 amount,
        address seller
    ) external override onlyRouter nonReentrant notPaused {
        require(price > 0, "WEM: invalid price");
        uint256 totalAmount = wastedsOnSale[seller][wastedId].amount.add(
            amount
        );
        wastedExpand.safeTransferFrom(
            seller,
            address(this),
            wastedId,
            amount,
            ""
        );

        wastedsOnSale[seller][wastedId].price = price;
        wastedsOnSale[seller][wastedId].amount = totalAmount;

        emit Listing(wastedId, price, totalAmount, seller);
    }

    function delist(uint256 wastedId, address caller)
        external
        override
        onlyRouter
        nonReentrant
        notPaused
    {
        uint256 amount = wastedsOnSale[caller][wastedId].amount;
        require(amount > 0, "WEM: invalid");

        wastedsOnSale[caller][wastedId].price = 0;
        wastedsOnSale[caller][wastedId].amount = 0;

        wastedExpand.transferFrom(address(this), caller, wastedId, amount, "");

        emit Delist(wastedId, caller);
    }

    function buy(
        uint256 wastedId,
        address seller,
        uint256 expectedPrice,
        address buyer
    ) external override onlyRouter nonReentrant notPaused returns (uint256) {
        uint256 price = wastedsOnSale[seller][wastedId].price;
        uint256 amount = wastedsOnSale[seller][wastedId].amount;
        uint256 currentOffer = wastedsOffer[buyer][wastedId].price;

        require(buyer != seller);
        require(price > 0, "WEM: not on sale");
        require(price == expectedPrice, "WEM: invalid price");

        if (currentOffer > 0) {
            wastedsOffer[buyer][wastedId].price = 0;
            wastedsOffer[buyer][wastedId].amount = 0;
            refundToken(buyer, currentOffer);
        }

        collectToken(buyer, address(this), price);

        _makeTransaction(wastedId, buyer, seller, price, amount);

        emit Bought(wastedId, buyer, seller, amount, price);

        return amount;
    }

    function offer(
        uint256 wastedId,
        uint256 offerPrice,
        address caller,
        uint256 amount
    ) external override nonReentrant notPaused returns (uint256) {
        address buyer = caller;
        uint256 currentOffer = wastedsOffer[buyer][wastedId].price;
        bool needRefund = offerPrice < currentOffer;
        uint256 requiredValue = needRefund ? 0 : offerPrice - currentOffer;

        require(offerPrice != currentOffer, "WEM: same offer");

        collectToken(buyer, address(this), requiredValue);
        wastedsOffer[buyer][wastedId].price = offerPrice;
        wastedsOffer[buyer][wastedId].amount = amount;

        if (needRefund) {
            uint256 returnedValue = currentOffer - offerPrice;

            refundToken(buyer, returnedValue);
        }

        emit Offered(wastedId, buyer, amount, offerPrice);

        return amount;
    }

    function acceptOffer(
        uint256 wastedId,
        address buyer,
        uint256 expectedPrice,
        address seller
    ) external override nonReentrant notPaused returns (uint256) {
        uint256 offeredPrice = wastedsOffer[buyer][wastedId].price;

        uint256 amount = wastedsOnSale[buyer][wastedId].amount;

        require(expectedPrice == offeredPrice);
        require(buyer != seller);

        wastedsOffer[buyer][wastedId].price = 0;
        wastedsOffer[buyer][wastedId].amount = 0;

        uint256 marketFee = (offeredPrice * marketFeeInPercent) / PERCENT;

        refundToken(seller, offeredPrice.sub(marketFee));

        if (marketFee > 0) {
            refundToken(owner(), marketFee);
        }

        wastedsOnSale[seller][wastedId].price = 0;
        wastedsOnSale[seller][wastedId].amount = 0;

        wastedExpand.safeTransferFrom(seller, buyer, wastedId, amount, "");

        emit Bought(wastedId, buyer, seller, amount, offeredPrice);

        return amount;
    }

    function abortOffer(
        uint256 wastedId,
        address seller,
        address caller
    ) external override nonReentrant notPaused {
        uint256 offerPrice = wastedsOffer[caller][wastedId].price;

        require(offerPrice > 0);

        wastedsOffer[caller][wastedId].price = 0;
        wastedsOffer[caller][wastedId].amount = 0;

        refundToken(caller, offerPrice);

        emit OfferCanceled(wastedId, seller, caller);
    }

    function _makeTransaction(
        uint256 wastedId,
        address buyer,
        address seller,
        uint256 price,
        uint256 amount
    ) private {
        uint256 marketFee = (price * marketFeeInPercent) / PERCENT;

        wastedsOnSale[seller][wastedId].price = 0;
        wastedsOnSale[seller][wastedId].amount = 0;

        refundToken(seller, price.sub(marketFee));

        if (marketFee > 0) {
            refundToken(owner(), marketFee);
        }

        wastedExpand.transferFrom(address(this), buyer, wastedId, amount, "");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
