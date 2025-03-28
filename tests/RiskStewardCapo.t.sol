// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {GovV3Helpers} from 'aave-helpers/src/GovV3Helpers.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {ConfigEngineDeployer} from './utils/ConfigEngineDeployer.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import {IPriceCapAdapterStable, IChainlinkAggregator} from 'aave-capo/interfaces/IPriceCapAdapterStable.sol';
import {PriceCapAdapterStable} from 'aave-capo/contracts/PriceCapAdapterStable.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

contract RiskSteward_Capo_Test is Test {
  using SafeCast for uint256;
  using SafeCast for int256;

  address public constant riskCouncil = address(42);
  RiskSteward public steward;
  uint104 currentRatio;
  uint48 delay;

  event AddressRestricted(address indexed contractAddress, bool indexed isRestricted);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20934847);

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 10_00 // 10%
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.priceCapConfig.priceCapLst = defaultRiskParamConfig;
    riskConfig.priceCapConfig.priceCapStable = defaultRiskParamConfig;

    steward = new RiskSteward(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      riskCouncil,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      riskConfig
    );

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));

    currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getRatio()
      .toUint256()
      .toUint104();
    delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    PriceCapAdapterStable mockAdapter = new PriceCapAdapterStable(
      IPriceCapAdapterStable.CapAdapterStableParams({
        assetToUsdAggregator: IChainlinkAggregator(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D),
        aclManager: AaveV3Ethereum.ACL_MANAGER,
        adapterDescription: 'Capped USDT / USD',
        priceCap: int256(1.04 * 1e8)
      })
    );
    vm.etch(AaveV3EthereumAssets.USDT_ORACLE, address(mockAdapter).code);
  }

  /* ----------------------------- LST Price Cap Tests ----------------------------- */

  function test_updateLstPriceCap() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio - 2),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateLstPriceCaps(priceCapUpdates);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.wstETH_ORACLE
    );

    uint256 snapshotRatioAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotRatio();
    uint256 snapshotTimestampAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotTimestamp();
    uint256 maxYearlyGrowthPercentAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    assertEq(snapshotTimestampAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotTimestamp);
    assertEq(snapshotRatioAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotRatio);
    assertEq(
      maxYearlyGrowthPercentAfter,
      priceCapUpdates[0].priceCapUpdateParams.maxYearlyRatioGrowthPercent
    );

    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - delay),
        snapshotRatio: (currentRatio - 1),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentAfter * 91) / 100).toUint16() // ~10% relative decrease
      })
    });

    steward.updateLstPriceCaps(priceCapUpdates);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.wstETH_ORACLE);

    snapshotRatioAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getSnapshotRatio();
    snapshotTimestampAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotTimestamp();
    maxYearlyGrowthPercentAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();
    assertEq(snapshotTimestampAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotTimestamp);
    assertEq(snapshotRatioAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotRatio);
    assertEq(
      maxYearlyGrowthPercentAfter,
      priceCapUpdates[0].priceCapUpdateParams.maxYearlyRatioGrowthPercent
    );
    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    vm.stopPrank();
  }

  function test_updateLstPriceCaps_debounceNotRespected() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio - 2),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 1 * delay),
        snapshotRatio: (currentRatio - 1),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore)).toUint16()
      })
    });

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateLstPriceCap_invalidRatio() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio + 1),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateLstPriceCap_outOfRange() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio - 1),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 120) / 100).toUint16() // 20% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as maxYearlyRatioGrowthPercent is out of range
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateLstPriceCap_isCapped() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio / 2),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as the price is being capped with the new parameters
    vm.expectRevert(IRiskSteward.InvalidPriceCapUpdate.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateLstPriceCap_toValueZeroNotAllowed() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: 0,
        snapshotRatio: (currentRatio / 2),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot timestamp is zero
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: 0,
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    // expect revert as snapshot ratio is zero
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio / 2),
        maxYearlyRatioGrowthPercent: 0
      })
    });

    // expect revert as maxYearlyRatioGrowthPercent is zero
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateLstPriceCap_oracleRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.wstETH_ORACLE, true);
    vm.stopPrank();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: (currentRatio / 2),
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthPercentBefore * 110) / 100).toUint16() // 10% relative increase
      })
    });

    vm.prank(riskCouncil);
    vm.expectRevert(IRiskSteward.OracleIsRestricted.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCap_noSameUpdate() public {
    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();
    uint256 snapshotTsBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotTimestamp();

    vm.startPrank(riskCouncil);
    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(snapshotTsBefore),
        snapshotRatio: currentRatio,
        maxYearlyRatioGrowthPercent: maxYearlyGrowthPercentBefore.toUint16() + 1
      })
    });

    // if same snapshot timestamp is used reverts
    vm.expectRevert(
      abi.encodeWithSelector(IPriceCapAdapter.InvalidRatioTimestamp.selector, snapshotTsBefore)
    );
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(snapshotTsBefore) + 1,
        snapshotRatio: currentRatio - 1,
        maxYearlyRatioGrowthPercent: maxYearlyGrowthPercentBefore.toUint16()
      })
    });

    // if same maxYearlyRatioGrowthPercent the steward should not revert
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  /* ----------------------------- Stable Price Cap Tests ----------------------------- */

  function test_updateStablePriceCap() public {
    uint256 priceCapBefore = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapBefore * 110) / 100) // +10% relative change
    });

    vm.startPrank(riskCouncil);
    steward.updateStablePriceCaps(priceCapUpdates);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(AaveV3EthereumAssets.USDT_ORACLE);

    uint256 priceCapAfter = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    assertEq(priceCapAfter, priceCapUpdates[0].priceCap);
    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapAfter * 90) / 100) // -10% relative change
    });

    steward.updateStablePriceCaps(priceCapUpdates);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.USDT_ORACLE);

    priceCapAfter = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    assertEq(priceCapAfter, priceCapUpdates[0].priceCap);
    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_debounceNotRespected() public {
    uint256 priceCapBefore = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapBefore * 110) / 100) // +10% relative change
    });

    vm.startPrank(riskCouncil);
    steward.updateStablePriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapBefore * 105) / 100)
    });

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateStablePriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_outOfRange() public {
    uint256 priceCapBefore = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapBefore * 120) / 100) // +20% relative change
    });

    // expect revert as price cap is out of range
    vm.startPrank(riskCouncil);

    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateStablePriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_keepCurrent_revert() public {
    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: EngineFlags.KEEP_CURRENT
    });

    // expect revert as price cap is out of range
    vm.startPrank(riskCouncil);

    vm.expectRevert();
    steward.updateStablePriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_toValueZeroNotAllowed() public {
    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: 0
    });

    // expect revert as price cap is out of range
    vm.startPrank(riskCouncil);

    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateStablePriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_oracleRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.USDT_ORACLE, true);
    vm.stopPrank();

    uint256 priceCapBefore = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: ((priceCapBefore * 110) / 100) // +10% relative change
    });

    // expect revert as price cap is out of range
    vm.startPrank(riskCouncil);

    vm.expectRevert(IRiskSteward.OracleIsRestricted.selector);
    steward.updateStablePriceCaps(priceCapUpdates);

    vm.stopPrank();
  }

  function test_updateStablePriceCap_sameUpdates() public {
    uint256 priceCapBefore = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: priceCapBefore
    });

    vm.startPrank(riskCouncil);
    steward.updateStablePriceCaps(priceCapUpdates);

    uint256 priceCapAfter = IPriceCapAdapterStable(AaveV3EthereumAssets.USDT_ORACLE)
      .getPriceCap()
      .toUint256();

    assertEq(priceCapBefore, priceCapAfter);
  }
}
