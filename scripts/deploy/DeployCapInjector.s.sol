// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {MiscOptimism} from 'aave-address-book/MiscOptimism.sol';
import {AaveV3Optimism, AaveV3OptimismAssets} from 'aave-address-book/AaveV3Optimism.sol';
import {MiscPolygon} from 'aave-address-book/MiscPolygon.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {MiscGnosis} from 'aave-address-book/MiscGnosis.sol';
import {AaveV3Gnosis, AaveV3GnosisAssets} from 'aave-address-book/AaveV3Gnosis.sol';
import {MiscBNB} from 'aave-address-book/MiscBNB.sol';
import {AaveV3BNB, AaveV3BNBAssets} from 'aave-address-book/AaveV3BNB.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {GovernanceV3Gnosis} from 'aave-address-book/GovernanceV3Gnosis.sol';
import {GovernanceV3BNB} from 'aave-address-book/GovernanceV3BNB.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardCaps, IRiskSteward} from '../../src/contracts/EdgeRiskStewardCaps.sol';
import {AaveStewardInjectorCaps} from '../../src/contracts/AaveStewardInjectorCaps.sol';
import {GelatoAaveStewardInjectorCaps} from '../../src/contracts/gelato/GelatoAaveStewardInjectorCaps.sol';

library DeployStewardContracts {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardCaps(
        pool,
        configEngine,
        riskCouncil,
        governance,
        _getRiskConfig()
      )
    );
    return riskSteward;
  }

  function _deployCapsStewardInjector(
    bytes32 salt,
    address create3Factory,
    address riskSteward,
    address owner,
    address guardian,
    address[] memory whitelistedMarkets,
    address riskOracle,
    bool isGelatoInjector
  ) internal returns (address) {
    bytes memory injectorCode = isGelatoInjector ?
      type(GelatoAaveStewardInjectorCaps).creationCode : type(AaveStewardInjectorCaps).creationCode;

    address stewardInjector = ICreate3Factory(create3Factory).create(
      salt,
      abi.encodePacked(
        injectorCode,
        abi.encode(riskOracle, riskSteward, whitelistedMarkets, owner, guardian)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        collateralConfig: IRiskSteward.CollateralConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          debtCeiling: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 20_00})
        }),
        eModeConfig: IRiskSteward.EmodeConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        }),
        rateConfig: IRiskSteward.RateConfig({
          baseVariableBorrowRate: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 1_00}),
          variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 1_00}),
          variableRateSlope2: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 20_00}),
          optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 3_00})
        }),
        capConfig: IRiskSteward.CapConfig({
          supplyCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 30_00}),
          borrowCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 30_00})
        }),
        priceCapConfig: IRiskSteward.PriceCapConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 5_00}),
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          discountRatePendle: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 5_00})
        })
      });
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  address constant GUARDIAN = 0x87dFb794364f2B117C8dbaE29EA622938b3Ce465;
  address constant RISK_ORACLE = 0x861eeAdB55E41f161F31Acb1BFD4c70E3a964Aed;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscArbitrum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Arbitrum.POOL),
      AaveV3Arbitrum.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Arbitrum.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](15);
    whitelistedMarkets[0] = AaveV3ArbitrumAssets.WETH_A_TOKEN;
    whitelistedMarkets[1] = AaveV3ArbitrumAssets.USDC_A_TOKEN;
    whitelistedMarkets[2] = AaveV3ArbitrumAssets.USDT_A_TOKEN;
    whitelistedMarkets[3] = AaveV3ArbitrumAssets.WBTC_A_TOKEN;
    whitelistedMarkets[4] = AaveV3ArbitrumAssets.DAI_A_TOKEN;
    whitelistedMarkets[5] = AaveV3ArbitrumAssets.weETH_A_TOKEN;
    whitelistedMarkets[6] = AaveV3ArbitrumAssets.ARB_A_TOKEN;
    whitelistedMarkets[7] = AaveV3ArbitrumAssets.USDCn_A_TOKEN;
    whitelistedMarkets[8] = AaveV3ArbitrumAssets.GHO_A_TOKEN;
    whitelistedMarkets[9] = AaveV3ArbitrumAssets.LINK_A_TOKEN;
    whitelistedMarkets[10] = AaveV3ArbitrumAssets.wstETH_A_TOKEN;
    whitelistedMarkets[11] = AaveV3ArbitrumAssets.LUSD_A_TOKEN;
    whitelistedMarkets[12] = AaveV3ArbitrumAssets.FRAX_A_TOKEN;
    whitelistedMarkets[13] = AaveV3ArbitrumAssets.rETH_A_TOKEN;
    whitelistedMarkets[14] = AaveV3ArbitrumAssets.AAVE_A_TOKEN;

    DeployStewardContracts._deployCapsStewardInjector(
      salt,
      MiscArbitrum.CREATE_3_FACTORY,
      riskSteward,
      GovernanceV3Arbitrum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets,
      RISK_ORACLE,
      false
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  address constant GUARDIAN = 0x9867Ce43D2a574a152fE6b134F64c9578ce3cE03;
  address constant RISK_ORACLE = 0x9f6aA2aB14bFF53e4b79A81ce1554F1DFdbb6608;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscOptimism.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Optimism.POOL),
      AaveV3Optimism.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Optimism.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](7);
    whitelistedMarkets[0] = AaveV3OptimismAssets.WETH_A_TOKEN;
    whitelistedMarkets[1] = AaveV3OptimismAssets.USDT_A_TOKEN;
    whitelistedMarkets[2] = AaveV3OptimismAssets.WBTC_A_TOKEN;
    whitelistedMarkets[3] = AaveV3OptimismAssets.USDCn_A_TOKEN;
    whitelistedMarkets[4] = AaveV3OptimismAssets.wstETH_A_TOKEN;
    whitelistedMarkets[5] = AaveV3OptimismAssets.rETH_A_TOKEN;
    whitelistedMarkets[6] = AaveV3OptimismAssets.OP_A_TOKEN;

    DeployStewardContracts._deployCapsStewardInjector(
      salt,
      MiscOptimism.CREATE_3_FACTORY,
      riskSteward,
      GovernanceV3Optimism.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets,
      RISK_ORACLE,
      false
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployPolygon chain=polygon
contract DeployPolygon is PolygonScript {
  address constant GUARDIAN = 0x7683177b05a92e8B169D833718BDF9d0ce809aA9;
  address constant RISK_ORACLE = 0x9f6aA2aB14bFF53e4b79A81ce1554F1DFdbb6608;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscPolygon.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Polygon.POOL),
      AaveV3Polygon.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Polygon.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](10);
    whitelistedMarkets[0] = AaveV3PolygonAssets.WETH_A_TOKEN;
    whitelistedMarkets[1] = AaveV3PolygonAssets.USDC_A_TOKEN;
    whitelistedMarkets[2] = AaveV3PolygonAssets.USDT0_A_TOKEN;
    whitelistedMarkets[3] = AaveV3PolygonAssets.WBTC_A_TOKEN;
    whitelistedMarkets[4] = AaveV3PolygonAssets.DAI_A_TOKEN;
    whitelistedMarkets[5] = AaveV3PolygonAssets.USDCn_A_TOKEN;
    whitelistedMarkets[6] = AaveV3PolygonAssets.LINK_A_TOKEN;
    whitelistedMarkets[7] = AaveV3PolygonAssets.wstETH_A_TOKEN;
    whitelistedMarkets[8] = AaveV3PolygonAssets.WPOL_A_TOKEN;
    whitelistedMarkets[9] = AaveV3PolygonAssets.AAVE_A_TOKEN;

    DeployStewardContracts._deployCapsStewardInjector(
      salt,
      MiscPolygon.CREATE_3_FACTORY,
      riskSteward,
      GovernanceV3Polygon.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets,
      RISK_ORACLE,
      false
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployGnosis chain=gnosis
contract DeployGnosis is GnosisScript {
  address constant GUARDIAN = 0x4bBBcfF03E94B2B661c5cA9c3BD34f6504591764;
  address constant RISK_ORACLE = 0x7BD97DD6C199532d11Cf5f55E13a120dB6dd0F4F;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapStewardInjectorV2';
    address predictedStewardsInjector = ICreate3Factory(MiscGnosis.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3Gnosis.POOL),
      AaveV3Gnosis.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3Gnosis.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](6);
    whitelistedMarkets[0] = AaveV3GnosisAssets.WETH_A_TOKEN;
    whitelistedMarkets[1] = AaveV3GnosisAssets.USDCe_A_TOKEN;
    whitelistedMarkets[2] = AaveV3GnosisAssets.sDAI_A_TOKEN;
    whitelistedMarkets[3] = AaveV3GnosisAssets.EURe_A_TOKEN;
    whitelistedMarkets[4] = AaveV3GnosisAssets.GNO_A_TOKEN;
    whitelistedMarkets[5] = AaveV3GnosisAssets.wstETH_A_TOKEN;

    DeployStewardContracts._deployCapsStewardInjector(
      salt,
      MiscGnosis.CREATE_3_FACTORY,
      riskSteward,
      GovernanceV3Gnosis.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets,
      RISK_ORACLE,
      true
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployBNB chain=bnb
contract DeployBNB is BNBScript {
  address constant GUARDIAN = 0xB5ABc2BcB050bE70EF53338E547d87d06F7c877d;
  address constant RISK_ORACLE = 0x239d3Bc5fa247337287cb03f53B8bc63DBBc332D;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscBNB.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      address(AaveV3BNB.POOL),
      AaveV3BNB.CONFIG_ENGINE,
      predictedStewardsInjector,
      GovernanceV3BNB.EXECUTOR_LVL_1
    );

    address[] memory whitelistedMarkets = new address[](6);
    whitelistedMarkets[0] = AaveV3BNBAssets.BTCB_A_TOKEN;
    whitelistedMarkets[1] = AaveV3BNBAssets.WBNB_A_TOKEN;
    whitelistedMarkets[2] = AaveV3BNBAssets.USDT_A_TOKEN;
    whitelistedMarkets[3] = AaveV3BNBAssets.USDC_A_TOKEN;
    whitelistedMarkets[4] = AaveV3BNBAssets.ETH_A_TOKEN;
    whitelistedMarkets[5] = AaveV3BNBAssets.wstETH_A_TOKEN;

    DeployStewardContracts._deployCapsStewardInjector(
      salt,
      MiscArbitrum.CREATE_3_FACTORY,
      riskSteward,
      GovernanceV3BNB.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets,
      RISK_ORACLE,
      false
    );
    vm.stopBroadcast();
  }
}
