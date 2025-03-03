// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3EthereumLido, AaveV3EthereumLidoAssets} from 'aave-address-book/AaveV3EthereumLido.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {IOwnable} from 'aave-address-book/common/IOwnable.sol';
import {EdgeRiskStewardRates, IRiskSteward, IPoolDataProvider, IEngine} from '../../src/contracts/EdgeRiskStewardRates.sol';
import {AaveStewardInjectorRates} from '../../src/contracts/AaveStewardInjectorRates.sol';

library DeployStewardContracts {
  address constant EDGE_RISK_ORACLE = 0x7ABB46C690C52E919687D19ebF89C81A6136C1F2;

  function _deployRiskStewards(
    address poolDataProvider,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardRates(
        IPoolDataProvider(poolDataProvider),
        IEngine(configEngine),
        riskCouncil,
        _getRiskConfig()
      )
    );
    IOwnable(riskSteward).transferOwnership(governance);
    return riskSteward;
  }

  function _deployRatesStewardInjector(
    bytes32 salt,
    address riskSteward,
    address owner,
    address guardian,
    address whitelistedAsset
  ) internal returns (address) {
    address stewardInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY).create(
      salt,
      abi.encodePacked(
        type(AaveStewardInjectorRates).creationCode,
        abi.encode(EDGE_RISK_ORACLE, riskSteward, owner, guardian, whitelistedAsset)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        ltv: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 25}),
        liquidationThreshold: IRiskSteward.RiskParamConfig({
          minDelay: 1 days,
          maxPercentChange: 25
        }),
        liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
        supplyCap: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 100_00}),
        borrowCap: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 100_00}),
        debtCeiling: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 20_00}),
        baseVariableBorrowRate: IRiskSteward.RiskParamConfig({
          minDelay: 1 days,
          maxPercentChange: 50
        }),
        variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
        variableRateSlope2: IRiskSteward.RiskParamConfig({
          minDelay: 1 days,
          maxPercentChange: 5_00
        }),
        optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 3_00}),
        priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 5_00}),
        priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50})
      });
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRateInjector.s.sol:DeployEthereumLido chain=mainnet
contract DeployEthereumLido is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'StewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3EthereumLido.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3EthereumLido.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    DeployStewardContracts._deployRatesStewardInjector(
      salt,
      riskSteward,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      AaveV3EthereumLidoAssets.WETH_UNDERLYING
    );
    vm.stopBroadcast();
  }
}
