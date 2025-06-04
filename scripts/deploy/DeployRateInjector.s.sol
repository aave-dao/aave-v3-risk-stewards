// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3EthereumLido, AaveV3EthereumLidoAssets} from 'aave-address-book/AaveV3EthereumLido.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardRates, IRiskSteward} from '../../src/contracts/EdgeRiskStewardRates.sol';
import {AaveStewardInjectorRates} from '../../src/contracts/AaveStewardInjectorRates.sol';

library DeployStewardContracts {
  struct DeployStewardInput {
    address pool;
    address configEngine;
    address riskCouncil;
    address governance;
  }

  struct DeployInjectorInput {
    address create3Factory;
    bytes32 salt;
    address riskSteward;
    address edgeRiskOracle;
    address owner;
    address guardian;
    address[] whitelistedMarkets;
  }

  function _deployRiskStewards(DeployStewardInput memory input) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardRates(
        input.pool,
        input.configEngine,
        input.riskCouncil,
        input.governance,
        _getRiskConfig()
      )
    );
    return riskSteward;
  }

  function _deployRatesStewardInjector(DeployInjectorInput memory input) internal returns (address) {
    address stewardInjector = ICreate3Factory(input.create3Factory).create(
      input.salt,
      abi.encodePacked(
        type(AaveStewardInjectorRates).creationCode,
        abi.encode(input.edgeRiskOracle, input.riskSteward, input.whitelistedMarkets, input.owner, input.guardian)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory config;
    config.rateConfig = IRiskSteward.RateConfig({
      baseVariableBorrowRate: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
      variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 1_00}),
      variableRateSlope2: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 5_00}),
      optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 3_00})
    });
    return config;
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRateInjector.s.sol:DeployEthereumLido chain=mainnet
contract DeployEthereumLido is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = 0x7ABB46C690C52E919687D19ebF89C81A6136C1F2;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'StewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      DeployStewardContracts.DeployStewardInput({
        pool: address(AaveV3EthereumLido.POOL),
        configEngine: AaveV3EthereumLido.CONFIG_ENGINE,
        riskCouncil: predictedStewardsInjector,
        governance: GovernanceV3Ethereum.EXECUTOR_LVL_1
      })
    );

    address[] memory whitelistedAssets = new address[](1);
    whitelistedAssets[0] = AaveV3EthereumLidoAssets.WETH_UNDERLYING;

    DeployStewardContracts._deployRatesStewardInjector(
      DeployStewardContracts.DeployInjectorInput({
        create3Factory: MiscEthereum.CREATE_3_FACTORY,
        salt: salt,
        riskSteward: riskSteward,
        edgeRiskOracle: EDGE_RISK_ORACLE,
        owner: GovernanceV3Ethereum.EXECUTOR_LVL_1,
        guardian: GUARDIAN,
        whitelistedMarkets: whitelistedAssets
      })
    );
    vm.stopBroadcast();
  }
}
