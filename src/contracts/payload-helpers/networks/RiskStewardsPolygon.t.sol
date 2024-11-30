// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsPolygon is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Polygon.POOL), AaveV3Polygon.RISK_STEWARD)
  {}
}
