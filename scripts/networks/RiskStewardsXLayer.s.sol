// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3XLayer} from 'aave-address-book/AaveV3XLayer.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsXLayer is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3XLayer.POOL), AaveV3XLayer.RISK_STEWARD)
  {}
}
