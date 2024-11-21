// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsArbitrum} from '../../../scripts/networks/RiskStewardsArbitrum.s.sol';

// make run-script network=arbitrum contract=src/contracts/examples/ArbitrumExample.sol:ArbitrumExample broadcast=false generate_diff=true
contract ArbitrumExample is RiskStewardsArbitrum {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'arbitrum_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate({
      asset: AaveV3ArbitrumAssets.wstETH_UNDERLYING,
      supplyCap: 75_600,
      borrowCap: EngineFlags.KEEP_CURRENT
    });
    return capUpdates;
  }
}
