// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {MiscLinea} from 'aave-address-book/MiscLinea.sol';
import {AaveV3EthereumLido, AaveV3EthereumLidoAssets} from 'aave-address-book/AaveV3EthereumLido.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Linea, AaveV3LineaAssets} from 'aave-address-book/AaveV3Linea.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Linea} from 'aave-address-book/GovernanceV3Linea.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardRates, IRiskSteward} from '../../src/contracts/EdgeRiskStewardRates.sol';
import {AaveStewardInjectorRates} from '../../src/contracts/AaveStewardInjectorRates.sol';
import {GelatoAaveStewardInjectorRates} from '../../src/contracts/gelato/GelatoAaveStewardInjectorRates.sol';

library DeployStewardContracts {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardRates(
        pool,
        configEngine,
        riskCouncil,
        governance,
        _getSlope2RiskConfig()
      )
    );
    return riskSteward;
  }

  function _deployRatesStewardInjector(
    address create3Factory,
    bytes32 salt,
    address riskSteward,
    address edgeRiskOracle,
    address owner,
    address guardian,
    address[] memory markets,
    bool isGelatoInjector
  ) internal returns (address) {
    bytes memory injectorCode = isGelatoInjector ?
      type(GelatoAaveStewardInjectorRates).creationCode : type(AaveStewardInjectorRates).creationCode;

    address stewardInjector = ICreate3Factory(create3Factory).create(
      salt,
      abi.encodePacked(
        injectorCode,
        abi.encode(edgeRiskOracle, riskSteward, markets, owner, guardian)
      )
    );
    return stewardInjector;
  }

  function _getSlope2RiskConfig() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory config;
    config.rateConfig.variableRateSlope2 = IRiskSteward.RiskParamConfig({minDelay: 8 hours, maxPercentChange: 4_00});

    return config;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        collateralConfig: IRiskSteward.CollateralConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          debtCeiling: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 20_00})
        }),
        eModeConfig: IRiskSteward.EmodeConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50})
        }),
        rateConfig: IRiskSteward.RateConfig({
          baseVariableBorrowRate: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 1_00}),
          variableRateSlope2: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 5_00}),
          optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 3_00})
        }),
        capConfig: IRiskSteward.CapConfig({
          supplyCap: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 100_00}),
          borrowCap: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 100_00})
        }),
        priceCapConfig: IRiskSteward.PriceCapConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 5_00}),
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 50}),
          discountRatePendle: IRiskSteward.RiskParamConfig({minDelay: 1 days, maxPercentChange: 5_00})
        })
      });
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
      address(AaveV3EthereumLido.POOL),
      AaveV3EthereumLido.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    address[] memory whitelistedAssets = new address[](1);
    whitelistedAssets[0] = AaveV3EthereumLidoAssets.WETH_UNDERLYING;

    DeployStewardContracts._deployRatesStewardInjector(
      MiscEthereum.CREATE_3_FACTORY,
      salt,
      riskSteward,
      EDGE_RISK_ORACLE,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedAssets,
      false
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRateInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = 0x7ABB46C690C52E919687D19ebF89C81A6136C1F2;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'StewardInjectorCore';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );

    address[] memory whitelistedAssets = new address[](4);
    whitelistedAssets[0] = AaveV3EthereumAssets.WETH_UNDERLYING;
    whitelistedAssets[1] = AaveV3EthereumAssets.USDC_UNDERLYING;
    whitelistedAssets[2] = AaveV3EthereumAssets.USDT_UNDERLYING;
    whitelistedAssets[3] = AaveV3EthereumAssets.USDe_UNDERLYING;

    DeployStewardContracts._deployRatesStewardInjector(
      MiscEthereum.CREATE_3_FACTORY,
      salt,
      riskSteward,
      EDGE_RISK_ORACLE,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedAssets,
      false
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRateInjector.s.sol:DeployLinea chain=linea
contract DeployLinea is LineaScript {
  address constant GUARDIAN = 0x0c28C535CE08345851F150dFC9c737978d726aEc;
  address constant EDGE_RISK_ORACLE = 0xa6C229d3a1D4D31708B16C0ad2f14337aE4E7893;
  address constant CREATE_3_FACTORY = 0x194a5828Fddf8782e6570149f0B2d31F8a1B89b6;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'StewardInjectorV2';
    address predictedStewardsInjector = ICreate3Factory(CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Linea.POOL),
      AaveV3Linea.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Linea.EXECUTOR_LVL_1
    );

    address[] memory whitelistedAssets = new address[](3);
    whitelistedAssets[0] = AaveV3LineaAssets.WETH_UNDERLYING;
    whitelistedAssets[1] = AaveV3LineaAssets.USDC_UNDERLYING;
    whitelistedAssets[2] = AaveV3LineaAssets.USDT_UNDERLYING;

    DeployStewardContracts._deployRatesStewardInjector(
      CREATE_3_FACTORY,
      salt,
      riskSteward,
      EDGE_RISK_ORACLE,
      GovernanceV3Linea.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedAssets,
      true
    );
    vm.stopBroadcast();
  }
}
