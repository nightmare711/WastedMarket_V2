const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const WastedMarket = artifacts.require('WastedMarket');

module.exports = async function (deployer) {
  const existing = await WastedMarket.deployed();
  const instance = await upgradeProxy(existing.address, WastedMarket, { deployer });
};