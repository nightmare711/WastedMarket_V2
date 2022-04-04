pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IWastedMarketRouter.sol";
import "./interface/IWastedMarketERC1155.sol";
import "./interface/IERC1155Support.sol";
import "./WastedMarketERC1155.sol";

contract WastedMarketRouter is IWastedMarketRouter, AccessControlUpgradeable {
    modifier onlySupportedAddress(IWastedMarketERC1155 _tuniverContract) {
        require(isSupported(address(_tuniverContract)), "WMR: unsupported");
        _;
    }

    mapping(address => bool) supportedAddress;
    bytes32 public CONTROLLER_ROLE;
    address public receiverFee;
    uint256 public fee;

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        receiverFee = msg.sender;
        CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    }

    function setSupportedAddress(
        IWastedMarketERC1155 _contractSupported,
        bool _isSupport
    ) external onlyRole(CONTROLLER_ROLE) {
        supportedAddress[address(_contractSupported)] = _isSupport;
        emit WastedMarketSupported(_contractSupported, _isSupport);
    }

    function setReceiverFee(address _receiverFee)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        receiverFee = _receiverFee;
    }

    function setFee(uint256 _fee) external onlyRole(CONTROLLER_ROLE) {
        fee = _fee;
    }

    function isSupported(address _contract) public view returns (bool) {
        return supportedAddress[_contract];
    }

    function createMarket(
        IERC1155Support wastedExpand_,
        uint256 marketFeeInPercent_,
        IERC20 tokenAddress
    ) external {
        WastedMarketERC1155 marketContract = new WastedMarketERC1155(
            wastedExpand_,
            marketFeeInPercent_,
            tokenAddress,
            address(this)
        );
        supportedAddress[address(marketContract)] = true;

        emit WastedMarketSupported(marketContract, true);
    }

    function listing(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        uint256 price,
        uint256 amount
    ) external {
        marketContract.listing(wastedId, price, amount, msg.sender);
        emit Listing(marketContract, wastedId, price, amount, msg.sender);
    }

    function offer(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        uint256 offerPrice,
        address seller
    ) external {
        marketContract.offer(wastedId, offerPrice, seller, msg.sender);
        emit Offered(marketContract, wastedId, msg.sender, seller, offerPrice);
    }

    function buy(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        address seller,
        uint256 expectedPrice
    ) external {
        uint256 amount = marketContract.buy(
            wastedId,
            seller,
            expectedPrice,
            msg.sender
        );

        emit Bought(
            marketContract,
            wastedId,
            msg.sender,
            seller,
            amount,
            expectedPrice
        );
    }

    function acceptOffer(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        address buyer,
        uint256 expectedPrice
    ) external {
        uint256 amount = marketContract.acceptOffer(
            wastedId,
            buyer,
            expectedPrice,
            msg.sender
        );

        emit Bought(
            marketContract,
            wastedId,
            buyer,
            msg.sender,
            amount,
            expectedPrice
        );
    }

    function abortOffer(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        address seller
    ) external {
        marketContract.abortOffer(wastedId, seller, msg.sender);

        emit OfferCanceled(marketContract, wastedId, seller, msg.sender);
    }

    function delist(IWastedMarketERC1155 marketContract, uint256 wastedId)
        external
    {
        marketContract.delist(wastedId, msg.sender);

        emit Delist(marketContract, wastedId, msg.sender);
    }

    function setPaused(IWastedMarketERC1155 marketContract, bool _isPaused)
        external
        onlyRole(CONTROLLER_ROLE)
        onlySupportedAddress(marketContract)
    {
        marketContract.switchPause(_isPaused);
    }
}
