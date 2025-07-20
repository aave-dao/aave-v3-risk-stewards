// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Linea} from 'aave-address-book/AaveV3Linea.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsLinea is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Linea.POOL), AaveV3Linea.RISK_STEWARD)
  {}
}
