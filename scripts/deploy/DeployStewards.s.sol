// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3EthereumLido} from 'aave-address-book/AaveV3EthereumLido.sol';
import {AaveV3EthereumEtherFi} from 'aave-address-book/AaveV3EthereumEtherFi.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {GovernanceV3Polygon} from 'aave-address-book/GovernanceV3Polygon.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {GovernanceV3Arbitrum} from 'aave-address-book/GovernanceV3Arbitrum.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {GovernanceV3Optimism} from 'aave-address-book/GovernanceV3Optimism.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {GovernanceV3Avalanche} from 'aave-address-book/GovernanceV3Avalanche.sol';
import {AaveV3Scroll} from 'aave-address-book/AaveV3Scroll.sol';
import {GovernanceV3Scroll} from 'aave-address-book/GovernanceV3Scroll.sol';
import {AaveV3Gnosis} from 'aave-address-book/AaveV3Gnosis.sol';
import {GovernanceV3Gnosis} from 'aave-address-book/GovernanceV3Gnosis.sol';
import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {GovernanceV3BNB} from 'aave-address-book/GovernanceV3BNB.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';
import {AaveV3Metis} from 'aave-address-book/AaveV3Metis.sol';
import {GovernanceV3Metis} from 'aave-address-book/GovernanceV3Metis.sol';
import {AaveV3Linea} from 'aave-address-book/AaveV3Linea.sol';
import {GovernanceV3Linea} from 'aave-address-book/GovernanceV3Linea.sol';
import {AaveV3Sonic} from 'aave-address-book/AaveV3Sonic.sol';
import {GovernanceV3Sonic} from 'aave-address-book/GovernanceV3Sonic.sol';
import {AaveV3Celo} from 'aave-address-book/AaveV3Celo.sol';
import {GovernanceV3Celo} from 'aave-address-book/GovernanceV3Celo.sol';
import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {GovernanceV3Plasma} from 'aave-address-book/GovernanceV3Plasma.sol';
import {AaveV3Mantle} from 'aave-address-book/AaveV3Mantle.sol';
import {GovernanceV3Mantle} from 'aave-address-book/GovernanceV3Mantle.sol';
import {AaveV3InkWhitelabel} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {GovernanceV3InkWhitelabel} from 'aave-address-book/GovernanceV3InkWhitelabel.sol';
import {AaveV3XLayer} from 'aave-address-book/AaveV3XLayer.sol';
import {GovernanceV3XLayer} from 'aave-address-book/GovernanceV3XLayer.sol';
import {AaveV3MegaEth} from 'aave-address-book/AaveV3MegaEth.sol';
import {GovernanceV3MegaEth} from 'aave-address-book/GovernanceV3MegaEth.sol';
import {AaveV3Soneium} from 'aave-address-book/AaveV3Soneium.sol';
import {GovernanceV3Soneium} from 'aave-address-book/GovernanceV3Soneium.sol';
import {AaveV3Monad} from 'aave-address-book/AaveV3Monad.sol';
import {GovernanceV3Monad} from 'aave-address-book/GovernanceV3Monad.sol';

import {RiskSteward, IRiskSteward} from '../../src/contracts/RiskSteward.sol';

library DeployRiskStewards {
  function _deployRiskStewards(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new RiskSteward(
        pool,
        configEngine,
        riskCouncil,
        governance,
        _getRiskConfig()
      )
    );
    return riskSteward;
  }

  function _deployRiskStewardsInk(
    address pool,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new RiskSteward(
        pool,
        configEngine,
        riskCouncil,
        governance,
        _getRiskConfigInk()
      )
    );
    return riskSteward;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        collateralConfig: IRiskSteward.CollateralConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        }),
        eModeConfig: IRiskSteward.EmodeConfig({
          ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 10}),
          liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        }),
        rateConfig: IRiskSteward.RateConfig({
          baseVariableBorrowRate: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 1_00}),
          variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 1_00}),
          variableRateSlope2: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 20_00}),
          optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 3_00})
        }),
        capConfig: IRiskSteward.CapConfig({
          supplyCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00}),
          borrowCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00})
        }),
        priceCapConfig: IRiskSteward.PriceCapConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 5_00}),
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
          discountRatePendle: IRiskSteward.RiskParamConfig({minDelay: 2 days, maxPercentChange: 0.025e18})
        })
      });
  }

  // as ink is a whitelabel instance and the minimum delay there has been reduced to 1 day while keeping the rest configs the same
  function _getRiskConfigInk() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory inkConfig = _getRiskConfig();

    inkConfig.collateralConfig.ltv.minDelay = 1 days;
    inkConfig.collateralConfig.liquidationThreshold.minDelay = 1 days;
    inkConfig.collateralConfig.liquidationBonus.minDelay = 1 days;

    inkConfig.eModeConfig.ltv.minDelay = 1 days;
    inkConfig.eModeConfig.liquidationThreshold.minDelay = 1 days;
    inkConfig.eModeConfig.liquidationBonus.minDelay = 1 days;

    inkConfig.rateConfig.baseVariableBorrowRate.minDelay = 1 days;
    inkConfig.rateConfig.variableRateSlope1.minDelay = 1 days;
    inkConfig.rateConfig.variableRateSlope2.minDelay = 1 days;
    inkConfig.rateConfig.optimalUsageRatio.minDelay = 1 days;

    inkConfig.capConfig.supplyCap.minDelay = 1 days;
    inkConfig.capConfig.borrowCap.minDelay = 1 days;

    inkConfig.priceCapConfig.priceCapLst.minDelay = 1 days;
    inkConfig.priceCapConfig.priceCapStable.minDelay = 1 days;
    // discountRatePendle keeps its 2-day delay

    return inkConfig;
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8, // eth-risk-council
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployEthereumLido chain=mainnet
contract DeployEthereumLido is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3EthereumLido.POOL),
      AaveV3EthereumLido.CONFIG_ENGINE,
      0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8, // eth-risk-council
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployEthereumEtherFi chain=mainnet
contract DeployEthereumEtherFi is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3EthereumEtherFi.POOL),
      AaveV3EthereumEtherFi.CONFIG_ENGINE,
      0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8, // eth-risk-council
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployPolygon chain=polygon
contract DeployPolygon is PolygonScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Polygon.POOL),
      AaveV3Polygon.CONFIG_ENGINE,
      0x2C40FB1ACe63084fc0bB95F83C31B5854C6C4cB5, // pol-risk-council
      GovernanceV3Polygon.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Arbitrum.POOL),
      AaveV3Arbitrum.CONFIG_ENGINE,
      0x3Be327F22eB4BD8042e6944073b8826dCf357Aa2, // arb-risk-council
      GovernanceV3Arbitrum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Optimism.POOL),
      AaveV3Optimism.CONFIG_ENGINE,
      0xCb86256A994f0c505c5e15c75BF85fdFEa0F2a56, // opt-risk-council
      GovernanceV3Optimism.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Avalanche.POOL),
      AaveV3Avalanche.CONFIG_ENGINE,
      0xCa66149425E7DC8f81276F6D80C4b486B9503D1a, // ava-risk-council
      GovernanceV3Avalanche.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployScroll chain=scroll
contract DeployScroll is ScrollScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Scroll.POOL),
      AaveV3Scroll.CONFIG_ENGINE,
      0x611439a74546888c3535B4dd119A5Cbb9f5332EA, // scroll-risk-council
      GovernanceV3Scroll.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployGnosis chain=gnosis
contract DeployGnosis is GnosisScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Gnosis.POOL),
      AaveV3Gnosis.CONFIG_ENGINE,
      0xF221B08dD10e0C68D74F035764931Baa3b030481, // gnosis-risk-council
      GovernanceV3Gnosis.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployBNB chain=bnb
contract DeployBNB is BNBScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3BNB.POOL),
      AaveV3BNB.CONFIG_ENGINE,
      0x126dc589cc75f17385dD95516F3F1788d862E7bc, // bnb-risk-council
      GovernanceV3BNB.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Base.POOL),
      AaveV3Base.CONFIG_ENGINE,
      0xfbeB4AcB31340bA4de9C87B11dfBf7e2bc8C0bF1, // base-risk-council
      GovernanceV3Base.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployMetis chain=metis
contract DeployMetis is MetisScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Metis.POOL),
      AaveV3Metis.CONFIG_ENGINE,
      0x0f547846920C34E70FBE4F3d87E46452a3FeAFfa, // metis-risk-council
      GovernanceV3Metis.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployLinea chain=linea
contract DeployLinea is LineaScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Linea.POOL),
      AaveV3Linea.CONFIG_ENGINE,
      0xF092A5aC5E284E7c433dAFE5b8B138bFcA53a4Ee, // linea-risk-council
      GovernanceV3Linea.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeploySonic chain=sonic
contract DeploySonic is SonicScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Sonic.POOL),
      AaveV3Sonic.CONFIG_ENGINE,
      0x1dE39A17a9Fa8c76899fff37488482EEb7835d04, // sonic-risk-council
      GovernanceV3Sonic.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployCelo chain=celo
contract DeployCelo is CeloScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Celo.POOL),
      AaveV3Celo.CONFIG_ENGINE,
      0xd85786B5FC61E2A0c0a3144a33A0fC70646a99f6, // celo-risk-council
      GovernanceV3Celo.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployPlasma chain=plasma
contract DeployPlasma is PlasmaScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Plasma.POOL),
      AaveV3Plasma.CONFIG_ENGINE,
      0xE71C189C7D8862EfDa0D9E031157199D2F3B4893, // plasma-risk-council
      GovernanceV3Plasma.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployMantle chain=mantle
contract DeployMantle is MantleScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Mantle.POOL),
      AaveV3Mantle.CONFIG_ENGINE,
      0xfF0ACe5060bd25f6900eb4bD91a868213C5346B5, // mantle-risk-council
      GovernanceV3Mantle.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployInk chain=ink
contract DeployInk is InkScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewardsInk(
      address(AaveV3InkWhitelabel.POOL),
      AaveV3InkWhitelabel.CONFIG_ENGINE,
      0xEcD37F855bB9814D75A83F0021815dc5cd6fd889, // ink-risk-council
      GovernanceV3InkWhitelabel.PERMISSIONED_PAYLOADS_CONTROLLER_EXECUTOR
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployXLayer chain=xlayer
contract DeployXLayer is XLayerScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3XLayer.POOL),
      AaveV3XLayer.CONFIG_ENGINE,
      0xa43F8eDf0a0aE07e951bca11162625e77e7609A1, // xlayer-risk-council
      GovernanceV3XLayer.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployMegaEth chain=megaeth
contract DeployMegaEth is MegaEthScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3MegaEth.POOL),
      AaveV3MegaEth.CONFIG_ENGINE,
      0x36CF7a4377aAf1988E01a4b38224FC8D583E50A9, // megaeth-risk-council
      GovernanceV3MegaEth.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeploySoneium chain=soneium
contract DeploySoneium is SoneiumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Soneium.POOL),
      AaveV3Soneium.CONFIG_ENGINE,
      0x45cCB319C57A6Ae0d53C4dB1a151dF75015103b1, // soneium-risk-council
      GovernanceV3Soneium.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployStewards.s.sol:DeployMonad chain=monad
contract DeployMonad is MonadScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Monad.POOL),
      AaveV3Monad.CONFIG_ENGINE,
      0x1c930A46f01542882Fb43031DeD31f06C8cF278d, // monad-risk-council
      GovernanceV3Monad.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}
