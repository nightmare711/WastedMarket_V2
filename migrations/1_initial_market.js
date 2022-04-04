const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const WastedMarket = artifacts.require("WastedMarket");
// Deploy new contract
module.exports = async function (deployer) {
  const instance = await deployProxy(WastedMarket, ["0xdeE71419bC45c11D28F9106cbb4923c7038Ed594", "0xd306c124282880858a634e7396383ae58d37c79c"], { initializer: 'initialize' });
  console.log('Deployed', instance.owner.call());
  // deployer.deploy(WastedWhitelist, '0xd1a4A413C0f11904CE952C074F35d4D091D13497');
};