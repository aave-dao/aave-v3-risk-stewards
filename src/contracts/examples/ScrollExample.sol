// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ScrollAssets} from 'aave-address-book/AaveV3Scroll.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsScroll} from '../payload-helpers/networks/RiskStewardsScroll.t.sol';

// make run-script network=scroll contract=src/contracts/examples/ScrollExample.sol:ScrollExample broadcast=false generate_diff=true
contract ScrollExample is RiskStewardsScroll {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'Scroll_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3ScrollAssets.wstETH_UNDERLYING,
      30_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
