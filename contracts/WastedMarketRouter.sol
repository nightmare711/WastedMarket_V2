//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IWastedMarketRouter.sol";
import "./interface/IWastedMarketERC1155.sol";
import "./interface/IERC1155Support.sol";
import "./WastedMarketERC1155.sol";

contract WastedMarketRouter is IWastedMarketRouter, AccessControlUpgradeable {
    modifier onlySupportedAddress(IWastedMarketERC1155 _tuniverContract) {
        require(isSupported(_tuniverContract), "WMR: unsupported");
        _;
    }

    mapping(IWastedMarketERC1155 => IERC1155Support) supportedAddress;
    bytes32 public CONTROLLER_ROLE;
    uint256 public fee;

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    }

    function unSupportedAddress(IWastedMarketERC1155 _contractSupported)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        supportedAddress[_contractSupported] = IERC1155Support(address(0));
        emit WastedMarketSupported(
            _contractSupported,
            IERC1155Support(address(0))
        );
    }

    function setFee(uint256 _fee) external onlyRole(CONTROLLER_ROLE) {
        fee = _fee;
    }

    function isSupported(IWastedMarketERC1155 _contract)
        public
        view
        returns (bool)
    {
        return address(supportedAddress[_contract]) != address(0);
    }

    function getWastedExpandSupported(IWastedMarketERC1155 _contract)
        public
        view
        returns (IERC1155Support)
    {
        return supportedAddress[_contract];
    }

    function createMarket(
        IERC1155Support wastedExpand_,
        uint256 marketFeeInPercent_,
        IERC20 tokenAddress
    ) external onlyRole(CONTROLLER_ROLE) {
        WastedMarketERC1155 marketContract = new WastedMarketERC1155(
            wastedExpand_,
            marketFeeInPercent_,
            tokenAddress,
            address(this)
        );
        supportedAddress[marketContract] = wastedExpand_;

        emit WastedMarketSupported(marketContract, wastedExpand_);
    }

    function listing(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        uint256 price,
        uint256 amount
    ) external onlySupportedAddress(marketContract) {
        uint256 totalAmount = marketContract.listing(
            wastedId,
            price,
            amount,
            msg.sender
        );
        emit Listing(marketContract, wastedId, price, totalAmount, msg.sender);
    }

    function offer(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        uint256 offerPrice,
        uint256 amount
    ) external onlySupportedAddress(marketContract) {
        marketContract.offer(wastedId, offerPrice, msg.sender, amount);
        emit Offered(marketContract, wastedId, msg.sender, offerPrice, amount);
    }

    function buy(
        IWastedMarketERC1155 marketContract,
        uint256 wastedId,
        address seller,
        uint256 expectedPrice
    ) external onlySupportedAddress(marketContract) {
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
    ) external onlySupportedAddress(marketContract) {
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

    function abortOffer(IWastedMarketERC1155 marketContract, uint256 wastedId)
        external
        onlySupportedAddress(marketContract)
    {
        marketContract.abortOffer(wastedId, msg.sender);

        emit OfferCanceled(marketContract, wastedId, msg.sender);
    }

    function delist(IWastedMarketERC1155 marketContract, uint256 wastedId)
        external
        onlySupportedAddress(marketContract)
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

    function setReceiverFee(
        IWastedMarketERC1155 marketContract,
        address _receiverFee
    ) external onlyRole(CONTROLLER_ROLE) {
        marketContract.setReceiverFee(_receiverFee);
    }
}
