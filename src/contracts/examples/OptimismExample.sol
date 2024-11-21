// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3OptimismAssets} from 'aave-address-book/AaveV3Optimism.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsOptimism} from '../../../scripts/networks/RiskStewardsOptimism.s.sol';

// make run-script network=optimism contract=src/contracts/examples/OptimismExample.sol:OptimismExample broadcast=false generate_diff=true
contract OptimismExample is RiskStewardsOptimism {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'optimism_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3OptimismAssets.wstETH_UNDERLYING,
      40_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
