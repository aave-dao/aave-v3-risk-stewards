// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsBaseChain is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Base.POOL), AaveV3Base.RISK_STEWARD)
  {}
}
