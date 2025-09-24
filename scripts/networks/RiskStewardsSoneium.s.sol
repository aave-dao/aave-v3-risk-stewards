// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Soneium} from 'aave-address-book/AaveV3Soneium.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsSoneium is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Soneium.POOL), AaveV3Soneium.RISK_STEWARD)
  {}
}
