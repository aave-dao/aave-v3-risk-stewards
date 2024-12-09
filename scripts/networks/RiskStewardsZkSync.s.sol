// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ZkSync} from 'aave-address-book/AaveV3ZkSync.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsZkSync is RiskStewardsBase {
  constructor() RiskStewardsBase(address(AaveV3ZkSync.POOL), AaveV3ZkSync.RISK_STEWARD) {}
}
