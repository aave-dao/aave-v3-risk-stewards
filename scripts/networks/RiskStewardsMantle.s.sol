// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Mantle} from 'aave-address-book/AaveV3Mantle.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsMantle is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Mantle.POOL), AaveV3Mantle.RISK_STEWARD)
  {}
}
