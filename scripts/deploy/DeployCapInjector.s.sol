// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscArbitrum} from 'aave-address-book/MiscArbitrum.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardCaps, IRiskSteward} from '../../src/contracts/EdgeRiskStewardCaps.sol';
import {AaveStewardInjectorCaps} from '../../src/contracts/AaveStewardInjectorCaps.sol';

library DeployStewardContracts {
  address constant EDGE_RISK_ORACLE = 0x861eeAdB55E41f161F31Acb1BFD4c70E3a964Aed;

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
    address riskSteward,
    address owner,
    address guardian,
    address[] memory whitelistedMarkets
  ) internal returns (address) {
    address stewardInjector = ICreate3Factory(MiscArbitrum.CREATE_3_FACTORY).create(
      salt,
      abi.encodePacked(
        type(AaveStewardInjectorCaps).creationCode,
        abi.encode(EDGE_RISK_ORACLE, riskSteward, msg.sender, guardian)
      )
    );
    AaveStewardInjectorCaps(stewardInjector).addMarkets(whitelistedMarkets);
    AaveStewardInjectorCaps(stewardInjector).transferOwnership(owner);
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
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        })
      });
  }
}

// make deploy-ledger contract=scripts/deploy/DeployCapInjector.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  address constant GUARDIAN = 0x87dFb794364f2B117C8dbaE29EA622938b3Ce465;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'CapsStewardInjector';
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
      riskSteward,
      GovernanceV3Arbitrum.EXECUTOR_LVL_1,
      GUARDIAN,
      whitelistedMarkets
    );
    vm.stopBroadcast();
  }
}
