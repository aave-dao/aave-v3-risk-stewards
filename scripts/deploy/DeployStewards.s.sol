// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import 'aave-address-book/AaveAddressBook.sol';
import {IOwnable} from 'aave-address-book/common/IOwnable.sol';
import {RiskSteward, IRiskSteward, IPoolDataProvider, IEngine} from '../../src/contracts/RiskSteward.sol';

library DeployRiskStewards {
  function _deployRiskStewards(
    address poolDataProvider,
    address configEngine,
    address riskCouncil,
    address governance
  ) internal returns (address) {
    address riskSteward = address(
      new RiskSteward(
        IPoolDataProvider(poolDataProvider),
        IEngine(configEngine),
        riskCouncil,
        _getRiskConfig()
      )
    );
    IOwnable(riskSteward).transferOwnership(governance);
    return riskSteward;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return IRiskSteward.Config({
      ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 3_00}),
      liquidationThreshold: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 3_00}),
      liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 2_00}),
      supplyCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00}),
      borrowCap: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00}),
      debtCeiling: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 100_00}),
      baseVariableBorrowRate: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 2_00}),
      variableRateSlope1: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 2_00}),
      variableRateSlope2: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 20_00}),
      optimalUsageRatio: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 10_00}),
      priceCapLst: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 15_00}),
      priceCapStable: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 2_00})
    });
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Ethereum.CONFIG_ENGINE,
      0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8, // eth-risk-council
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployEthereumLido chain=mainnet
contract DeployEthereumLido is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3EthereumLido.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3EthereumLido.CONFIG_ENGINE,
      0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8, // eth-risk-council
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployPolygon chain=polygon
contract DeployPolygon is PolygonScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Polygon.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Polygon.CONFIG_ENGINE,
      0x2C40FB1ACe63084fc0bB95F83C31B5854C6C4cB5, // pol-risk-council
      GovernanceV3Polygon.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployArbitrum chain=arbitrum
contract DeployArbitrum is ArbitrumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Arbitrum.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Arbitrum.CONFIG_ENGINE,
      0x3Be327F22eB4BD8042e6944073b8826dCf357Aa2, // arb-risk-council
      GovernanceV3Arbitrum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployOptimism chain=optimism
contract DeployOptimism is OptimismScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Optimism.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Optimism.CONFIG_ENGINE,
      0xCb86256A994f0c505c5e15c75BF85fdFEa0F2a56, // opt-risk-council
      GovernanceV3Optimism.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Avalanche.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Avalanche.CONFIG_ENGINE,
      0xCa66149425E7DC8f81276F6D80C4b486B9503D1a, // ava-risk-council
      GovernanceV3Avalanche.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployScroll chain=scroll
contract DeployScroll is ScrollScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Scroll.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Scroll.CONFIG_ENGINE,
      0x611439a74546888c3535B4dd119A5Cbb9f5332EA, // scroll-risk-council
      GovernanceV3Scroll.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployGnosis chain=gnosis
contract DeployGnosis is GnosisScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Gnosis.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Gnosis.CONFIG_ENGINE,
      0xF221B08dD10e0C68D74F035764931Baa3b030481, // gnosis-risk-council
      GovernanceV3Gnosis.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployBNB chain=bnb
contract DeployBNB is BNBScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3BNB.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3BNB.CONFIG_ENGINE,
      0x126dc589cc75f17385dD95516F3F1788d862E7bc, // bnb-risk-council
      GovernanceV3BNB.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Base.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Base.CONFIG_ENGINE,
      0xfbeB4AcB31340bA4de9C87B11dfBf7e2bc8C0bF1, // base-risk-council
      GovernanceV3Base.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/DeployStewards.s.sol:DeployMetis chain=metis
contract DeployMetis is MetisScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskStewards(
      address(AaveV3Metis.AAVE_PROTOCOL_DATA_PROVIDER),
      AaveV3Metis.CONFIG_ENGINE,
      0x0f547846920C34E70FBE4F3d87E46452a3FeAFfa, // metis-risk-council
      GovernanceV3Metis.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}
