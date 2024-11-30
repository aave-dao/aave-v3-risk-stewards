// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsOptimism is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Optimism.POOL), AaveV3Optimism.RISK_STEWARD)
  {}
}
