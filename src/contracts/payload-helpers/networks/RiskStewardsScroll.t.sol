// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Scroll} from 'aave-address-book/AaveV3Scroll.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsScroll is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Scroll.POOL), AaveV3Scroll.RISK_STEWARD)
  {}
}
