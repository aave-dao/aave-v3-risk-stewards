// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3BNBAssets} from 'aave-address-book/AaveV3BNB.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsBNB} from '../../../scripts/networks/RiskStewardsBNB.s.sol';

// make run-script network=bnb contract_path=src/contracts/examples/BNBExample.sol:BNBExample broadcast=false
contract BNBExample is RiskStewardsBNB {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'bnb_example';
  }

  function rateStrategiesUpdates() public pure override returns (IEngine.RateStrategyUpdate[] memory) {
    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3BNBAssets.ETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: 85_00,
        baseVariableBorrowRate: 1_00,
        variableRateSlope1: 3_00,
        variableRateSlope2: 90_00
      })
    });

    return rateUpdates;
  }
}
