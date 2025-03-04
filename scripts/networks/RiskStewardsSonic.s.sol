// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Sonic} from 'aave-address-book/AaveV3Sonic.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsSonic is RiskStewardsBase {
  constructor() RiskStewardsBase(address(AaveV3Sonic.POOL), AaveV3Sonic.RISK_STEWARD) {}
}
