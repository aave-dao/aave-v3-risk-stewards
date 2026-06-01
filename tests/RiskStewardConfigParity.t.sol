// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3EthereumLido} from 'aave-address-book/AaveV3EthereumLido.sol';
import {AaveV3EthereumEtherFi} from 'aave-address-book/AaveV3EthereumEtherFi.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Scroll} from 'aave-address-book/AaveV3Scroll.sol';
import {AaveV3Gnosis} from 'aave-address-book/AaveV3Gnosis.sol';
import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {AaveV3Linea} from 'aave-address-book/AaveV3Linea.sol';
import {AaveV3Sonic} from 'aave-address-book/AaveV3Sonic.sol';
import {AaveV3Celo} from 'aave-address-book/AaveV3Celo.sol';
import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {AaveV3Mantle} from 'aave-address-book/AaveV3Mantle.sol';
import {AaveV3InkWhitelabel} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {AaveV3XLayer} from 'aave-address-book/AaveV3XLayer.sol';
import {AaveV3MegaEth} from 'aave-address-book/AaveV3MegaEth.sol';
import {AaveV3ZkSync} from 'aave-address-book/AaveV3ZkSync.sol';
import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';
import {DeployRiskStewards} from '../scripts/deploy/DeployStewards.s.sol';

// forge test --match-path tests/RiskStewardConfigParity.t.sol -vv
// validates that the risk configs on the stewards to be deployed matches the current risk-steward configs
abstract contract RiskStewardConfigParityTestBase is Test {
  function _verifyConfigParity(address onChainSteward) internal view {
    _verifyConfigParity(onChainSteward, DeployRiskStewards._getRiskConfig());
  }

  function _verifyConfigParity(
    address onChainSteward,
    IRiskSteward.Config memory toDeploy
  ) internal view {
    IRiskSteward.Config memory onChain = IRiskSteward(onChainSteward).getRiskConfig();

    // collateral
    _assertParamEq(onChain.collateralConfig.ltv, toDeploy.collateralConfig.ltv, 'collateral.ltv');
    _assertParamEq(
      onChain.collateralConfig.liquidationThreshold,
      toDeploy.collateralConfig.liquidationThreshold,
      'collateral.liquidationThreshold'
    );
    _assertParamEq(
      onChain.collateralConfig.liquidationBonus,
      toDeploy.collateralConfig.liquidationBonus,
      'collateral.liquidationBonus'
    );

    // eMode
    _assertParamEq(onChain.eModeConfig.ltv, toDeploy.eModeConfig.ltv, 'eMode.ltv');
    _assertParamEq(
      onChain.eModeConfig.liquidationThreshold,
      toDeploy.eModeConfig.liquidationThreshold,
      'eMode.liquidationThreshold'
    );
    _assertParamEq(
      onChain.eModeConfig.liquidationBonus,
      toDeploy.eModeConfig.liquidationBonus,
      'eMode.liquidationBonus'
    );

    // rates
    _assertParamEq(
      onChain.rateConfig.baseVariableBorrowRate,
      toDeploy.rateConfig.baseVariableBorrowRate,
      'rate.baseVariableBorrowRate'
    );
    _assertParamEq(
      onChain.rateConfig.variableRateSlope1,
      toDeploy.rateConfig.variableRateSlope1,
      'rate.variableRateSlope1'
    );
    _assertParamEq(
      onChain.rateConfig.variableRateSlope2,
      toDeploy.rateConfig.variableRateSlope2,
      'rate.variableRateSlope2'
    );
    _assertParamEq(
      onChain.rateConfig.optimalUsageRatio,
      toDeploy.rateConfig.optimalUsageRatio,
      'rate.optimalUsageRatio'
    );

    // caps
    _assertParamEq(onChain.capConfig.supplyCap, toDeploy.capConfig.supplyCap, 'cap.supplyCap');
    _assertParamEq(onChain.capConfig.borrowCap, toDeploy.capConfig.borrowCap, 'cap.borrowCap');

    // price caps
    _assertParamEq(
      onChain.priceCapConfig.priceCapLst,
      toDeploy.priceCapConfig.priceCapLst,
      'priceCap.priceCapLst'
    );
    _assertParamEq(
      onChain.priceCapConfig.priceCapStable,
      toDeploy.priceCapConfig.priceCapStable,
      'priceCap.priceCapStable'
    );
    _assertParamEq(
      onChain.priceCapConfig.discountRatePendle,
      toDeploy.priceCapConfig.discountRatePendle,
      'priceCap.discountRatePendle'
    );
  }

  function _assertParamEq(
    IRiskSteward.RiskParamConfig memory a,
    IRiskSteward.RiskParamConfig memory b,
    string memory label
  ) internal pure {
    assertEq(a.minDelay, b.minDelay, string.concat(label, '.minDelay mismatch'));
    assertEq(
      a.maxPercentChange,
      b.maxPercentChange,
      string.concat(label, '.maxPercentChange mismatch')
    );
  }
}

contract RiskStewardConfigParity_Ethereum is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25223478);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Ethereum.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_EthereumLido is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25223478);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3EthereumLido.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Polygon is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 87764949);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Polygon.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Arbitrum is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 468973218);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Arbitrum.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Optimism is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('optimism'), 152364802);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Optimism.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Avalanche is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 86920959);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Avalanche.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Scroll is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('scroll'), 33913931);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Scroll.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Gnosis is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('gnosis'), 46475668);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Gnosis.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_BNB is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('bnb'), 101715204);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3BNB.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Base is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('base'), 46769518);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Base.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Linea is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('linea'), 30862157);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Linea.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Sonic is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('sonic'), 72064422);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Sonic.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Celo is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('celo'), 68427627);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Celo.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Plasma is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('plasma'), 23388493);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Plasma.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Mantle is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mantle'), 96099037);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3Mantle.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_Ink is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('ink'), 46829976);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3InkWhitelabel.RISK_STEWARD, DeployRiskStewards._getRiskConfigInk());
  }
}

contract RiskStewardConfigParity_XLayer is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('xlayer'), 61559351);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3XLayer.RISK_STEWARD);
  }
}

contract RiskStewardConfigParity_MegaEth is RiskStewardConfigParityTestBase {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('megaeth'), 17531376);
  }

  function test_configParity() public view {
    _verifyConfigParity(AaveV3MegaEth.RISK_STEWARD);
  }
}
