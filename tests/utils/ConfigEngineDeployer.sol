// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {Create2Utils} from 'aave-v3-core/../deployments/contracts/utilities/Create2Utils.sol';
import {AaveV3ConfigEngine} from 'aave-v3-periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {IAaveV3ConfigEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IPoolAddressesProvider} from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {IAaveOracle} from 'aave-v3-core/contracts/interfaces/IAaveOracle.sol';
import {CapsEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/CapsEngine.sol';
import {BorrowEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/BorrowEngine.sol';
import {CollateralEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/CollateralEngine.sol';
import {RateEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/RateEngine.sol';
import {PriceFeedEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/PriceFeedEngine.sol';
import {EModeEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/EModeEngine.sol';
import {ListingEngine} from 'aave-v3-periphery/contracts/v3-config-engine/libraries/ListingEngine.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';

library ConfigEngineDeployer {
  function deployEngine(address interestRateStrategy) internal returns (address) {
    IAaveV3ConfigEngine.EngineLibraries memory engineLibraries = IAaveV3ConfigEngine
      .EngineLibraries({
        listingEngine: Create2Utils._create2Deploy('v1', type(ListingEngine).creationCode),
        eModeEngine: Create2Utils._create2Deploy('v1', type(EModeEngine).creationCode),
        borrowEngine: Create2Utils._create2Deploy('v1', type(BorrowEngine).creationCode),
        collateralEngine: Create2Utils._create2Deploy('v1', type(CollateralEngine).creationCode),
        priceFeedEngine: Create2Utils._create2Deploy('v1', type(PriceFeedEngine).creationCode),
        rateEngine: Create2Utils._create2Deploy('v1', type(RateEngine).creationCode),
        capsEngine: Create2Utils._create2Deploy('v1', type(CapsEngine).creationCode)
      });

    IAaveV3ConfigEngine.EngineConstants memory engineConstants = IAaveV3ConfigEngine
      .EngineConstants({
        pool: IPool(address(AaveV3Ethereum.POOL)),
        poolConfigurator: IPoolConfigurator(address(AaveV3Ethereum.POOL_CONFIGURATOR)),
        defaultInterestRateStrategy: interestRateStrategy,
        oracle: IAaveOracle(address(AaveV3Ethereum.ORACLE)),
        rewardsController: AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
        collector: address(AaveV3Ethereum.COLLECTOR)
      });

    return
      address(
        new AaveV3ConfigEngine(
          AaveV3Ethereum.DEFAULT_A_TOKEN_IMPL_REV_1,
          AaveV3Ethereum.DEFAULT_VARIABLE_DEBT_TOKEN_IMPL_REV_1,
          AaveV3Ethereum.DEFAULT_STABLE_DEBT_TOKEN_IMPL_REV_1,
          engineConstants,
          engineLibraries
        )
      );
  }
}
