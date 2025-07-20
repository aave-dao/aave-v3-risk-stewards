// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3BaseAssets} from 'aave-address-book/AaveV3Base.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsBaseChain} from '../../../scripts/networks/RiskStewardsBaseChain.s.sol';

// make run-script network=base contract=src/contracts/examples/BaseExample.sol:BaseExample broadcast=false generate_diff=true skip_timelock=false
contract BaseExample is RiskStewardsBaseChain {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'base_example';
  }

  function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](2);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3BaseAssets.USDC_UNDERLYING,
      ltv: 77_00,
      liqThreshold: 79_00,
      liqBonus: 6_00,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });
    collateralUpdates[1] = IEngine.CollateralUpdate({
      asset: AaveV3BaseAssets.WETH_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: 84_00,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    return collateralUpdates;
  }
}
