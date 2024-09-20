// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3BNB} from 'aave-address-book/AaveV3BNB.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsBNB is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3BNB.POOL), AaveV3BNB.RISK_STEWARD)
  {}
}
