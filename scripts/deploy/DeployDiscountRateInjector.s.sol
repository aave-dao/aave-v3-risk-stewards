// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardDiscountRate, IRiskSteward} from '../../src/contracts/EdgeRiskStewardDiscountRate.sol';
import {AaveStewardInjectorDiscountRate} from '../../src/contracts/AaveStewardInjectorDiscountRate.sol';

library DeployStewardContracts {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardDiscountRate(pool, configEngine, riskCouncil, governance, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployDiscountRateStewardInjector(
    address create3Factory,
    bytes32 salt,
    address riskSteward,
    address aaveOracle,
    address edgeRiskOracle,
    address owner,
    address guardian,
    address[] memory whitelistedMarkets
  ) internal returns (address) {
    address stewardInjector = ICreate3Factory(create3Factory).create(
      salt,
      abi.encodePacked(
        type(AaveStewardInjectorDiscountRate).creationCode,
        abi.encode(aaveOracle, edgeRiskOracle, riskSteward, whitelistedMarkets, owner, guardian)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory config;
    config.priceCapConfig.discountRatePendle = IRiskSteward.RiskParamConfig({
      minDelay: 2 days,
      maxPercentChange: 0.01e18 // 1%
    });

    return config;
  }
}

// make deploy-ledger contract=scripts/deploy/DeployDiscountRateInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = 0x7ABB46C690C52E919687D19ebF89C81A6136C1F2;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'DiscountRateStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    address[] memory whitelistedPendleAssets = new address[](3);
    whitelistedPendleAssets[0] = AaveV3EthereumAssets.PT_sUSDE_31JUL2025_UNDERLYING;
    whitelistedPendleAssets[1] = AaveV3EthereumAssets.PT_USDe_31JUL2025_UNDERLYING;
    whitelistedPendleAssets[2] = AaveV3EthereumAssets.PT_eUSDE_14AUG2025_UNDERLYING;

    DeployStewardContracts._deployDiscountRateStewardInjector(
      MiscEthereum.CREATE_3_FACTORY,
      salt,
      riskSteward,
      address(AaveV3Ethereum.ORACLE),
      EDGE_RISK_ORACLE,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedPendleAssets
    );
    vm.stopBroadcast();
  }
}
