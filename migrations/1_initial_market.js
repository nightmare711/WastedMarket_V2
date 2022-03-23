const WastedMarket = artifacts.require("WastedMarket");

module.exports = function (deployer) {
  deployer.deploy(WastedMarket, "0x157B9dC01CE3993f45580C1036065Ec18Ad649e5", "0xA4441b7f6FD28814e29116C7bdeF0574e8288B8E");
};
