// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-periphery/contracts/v3-config-engine/EngineFlags.sol';
import {RiskStewardsArbitrum} from '../../../scripts/networks/RiskStewardsArbitrum.s.sol';

// make run-script network=arbitrum contract_path=src/contracts/examples/ArbitrumExample.s.sol:ArbitrumExample broadcast=false
contract ArbitrumExample is RiskStewardsArbitrum {
  /**
   * @return string name identifier used for the diff
   */
  function name() internal pure override returns (string memory) {
    return 'arbitrum_example';
  }

  function capsUpdates() internal pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate({
      asset: AaveV3ArbitrumAssets.wstETH_UNDERLYING,
      supplyCap: 75_600,
      borrowCap: EngineFlags.KEEP_CURRENT
    });
    return capUpdates;
  }
}
