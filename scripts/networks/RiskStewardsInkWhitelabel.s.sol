// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3InkWhitelabel} from 'aave-address-book/AaveV3InkWhitelabel.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsInkWhitelabel is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3InkWhitelabel.POOL), AaveV3InkWhitelabel.RISK_STEWARD)
  {}
}
