// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardCollateral, IRiskSteward} from '../../src/contracts/EdgeRiskStewardCollateral.sol';
import {AaveStewardInjectorCollateral} from '../../src/contracts/AaveStewardInjectorCollateral.sol';

library DeployStewardContracts {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardCollateral(pool, configEngine, riskCouncil, governance, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployCollateralStewardInjector(
    address create3Factory,
    bytes32 salt,
    address riskSteward,
    address edgeRiskOracle,
    address owner,
    address guardian,
    address[] memory whitelistedMarkets
  ) internal returns (address) {
    address stewardInjector = ICreate3Factory(create3Factory).create(
      salt,
      abi.encodePacked(
        type(AaveStewardInjectorCollateral).creationCode,
        abi.encode(edgeRiskOracle, riskSteward, msg.sender, guardian)
      )
    );
    AaveStewardInjectorCollateral(stewardInjector).addMarkets(whitelistedMarkets);
    AaveStewardInjectorCollateral(stewardInjector).transferOwnership(owner);
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        collateralConfig: IRiskSteward.CollateralConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 50
          }),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          debtCeiling: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 20_00})
        }),
        eModeConfig: IRiskSteward.EmodeConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 50
          }),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        }),
        rateConfig: IRiskSteward.RateConfig({
          baseVariableBorrowRate: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 1_00
          }),
          variableRateSlope1: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 1_00
          }),
          variableRateSlope2: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 20_00
          }),
          optimalUsageRatio: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 3_00
          })
        }),
        capConfig: IRiskSteward.CapConfig({
          supplyCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 30_00}),
          borrowCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 30_00})
        }),
        priceCapConfig: IRiskSteward.PriceCapConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 5_00}),
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          discountRatePendle: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 20_00
          })
        })
      });
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCollateralInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = address(0); // TODO

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CollateralStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](1);
    whitelistedMarkets[0] = address(0); // TODO: add listed pendle PT asset

    DeployStewardContracts._deployCollateralStewardInjector(
      MiscEthereum.CREATE_3_FACTORY,
      salt,
      riskSteward,
      EDGE_RISK_ORACLE,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets
    );
    vm.stopBroadcast();
  }
}
