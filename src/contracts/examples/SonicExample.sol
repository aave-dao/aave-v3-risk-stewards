// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3SonicAssets} from 'aave-address-book/AaveV3Sonic.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsSonic} from '../../../scripts/networks/RiskStewardsSonic.s.sol';

// make run-script network=optimism contract=src/contracts/examples/SonicExample.sol:SonicExample broadcast=false generate_diff=true skip_timelock=false
contract SonicExample is RiskStewardsSonic {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'sonic_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3SonicAssets.wS_UNDERLYING,
      21_000_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
