// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardEMode, IRiskSteward} from '../../src/contracts/EdgeRiskStewardEMode.sol';
import {AaveStewardInjectorEMode} from '../../src/contracts/AaveStewardInjectorEMode.sol';

library DeployStewardContracts {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardEMode(pool, configEngine, riskCouncil, governance, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployEModeStewardInjector(
    address create3Factory,
    bytes32 salt,
    address riskSteward,
    address edgeRiskOracle,
    address owner,
    address guardian,
    uint8[] memory whitelistedEModes
  ) internal returns (address) {
    address[] memory whitelistedMarkets = new address[](whitelistedEModes.length);
    for (uint256 i = 0; i < whitelistedEModes.length; i++) {
      whitelistedMarkets[i] = address(uint160(whitelistedEModes[i]));
    }

    address stewardInjector = ICreate3Factory(create3Factory).create(
      salt,
      abi.encodePacked(
        type(AaveStewardInjectorEMode).creationCode,
        abi.encode(edgeRiskOracle, riskSteward, whitelistedMarkets, owner, guardian)
      )
    );
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
            minDelay: 2 days,
            maxPercentChange: 5_00
          })
        })
      });
  }
}

// make deploy-ledger contract=scripts/deploy/DeployEModeInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = address(0); // TODO

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'EModeStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    uint8[] memory whitelistedEModes = new uint8[](1);
    whitelistedEModes[0] = 8;

    DeployStewardContracts._deployEModeStewardInjector(
      MiscEthereum.CREATE_3_FACTORY,
      salt,
      riskSteward,
      EDGE_RISK_ORACLE,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedEModes
    );
    vm.stopBroadcast();
  }
}
