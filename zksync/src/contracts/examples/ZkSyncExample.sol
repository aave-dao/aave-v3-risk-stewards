// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ZkSyncAssets} from 'aave-address-book/AaveV3ZkSync.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsZkSync} from '../../../../scripts/networks/RiskStewardsZkSync.s.sol';

// make run-script network=zksync contract=zksync/src/contracts/examples/ZkSyncExample.sol broadcast=false generate_diff=true skip_timelock=false
contract ZkSyncExample is RiskStewardsZkSync {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'zksync_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate({
      asset: AaveV3ZkSyncAssets.USDC_UNDERLYING,
      supplyCap: 2_500_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });
    return capUpdates;
  }
}
