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
          supplyCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00}),
          borrowCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00})
        }),
        priceCapConfig: IRiskSteward.PriceCapConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 5_00}),
          priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
        })
      });
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
contract DeployCelo is SonicScript {
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
