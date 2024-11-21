// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveV3ConfigEngine as IEngine, IPool} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IRiskSteward} from '../src/interfaces/IRiskSteward.sol';
import {ProtocolV3TestBase} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {IOwnable} from 'aave-address-book/common/IOwnable.sol';
import {IACLManager} from 'aave-address-book/AaveV3.sol';

abstract contract RiskStewardsBase is ProtocolV3TestBase {
  error FailedUpdate();
  IPool immutable POOL;
  IRiskSteward immutable STEWARD;

  uint8 public constant MAX_TX = 5;

  constructor(address pool, address steward) {
    POOL = IPool(pool);
    STEWARD = IRiskSteward(steward);
  }

  function capsUpdates() public pure virtual returns (IEngine.CapsUpdate[] memory) {}

  function collateralsUpdates() public pure virtual returns (IEngine.CollateralUpdate[] memory) {}

  function rateStrategiesUpdates()
    public
    pure
    virtual
    returns (IEngine.RateStrategyUpdate[] memory)
  {}

  function lstPriceCapsUpdates() public pure virtual returns (IRiskSteward.PriceCapLstUpdate[] memory) {}

  function stablePriceCapsUpdates() public pure virtual returns (IRiskSteward.PriceCapStableUpdate[] memory) {}

  function name() public pure virtual returns (string memory);

  /**
   * @notice This script doesn't broadcast as it's intended to be used via safe
   */
  function run(bool broadcastToSafe, bool generateDiffReport) external {
    vm.startPrank(STEWARD.RISK_COUNCIL());
    bytes[] memory callDatas = _simulateAndGenerateDiff(generateDiffReport);
    vm.stopPrank();

    if (callDatas.length > 1) emit log_string('** multiple calldatas emitted, please execute them all **');
    emit log_string('safe address');
    emit log_address(STEWARD.RISK_COUNCIL());
    emit log_string('steward address:');
    emit log_address(address(STEWARD));

    for (uint8 i = 0; i < callDatas.length; i++) {
      emit log_string('calldata:');
      emit log_bytes(callDatas[i]);

      if (broadcastToSafe) {
        _sendToSafe(callDatas[i]);
      }
    }
  }

  function _simulateAndGenerateDiff(bool generateDiffReport) internal returns (bytes[] memory) {
    bytes[] memory callDatas = new bytes[](MAX_TX);
    uint8 txCount;

    string memory pre = string(abi.encodePacked('pre_', name()));
    string memory post = string(abi.encodePacked('post_', name()));

    IEngine.CapsUpdate[] memory capUpdates = capsUpdates();
    IEngine.CollateralUpdate[] memory collateralUpdates = collateralsUpdates();
    IEngine.RateStrategyUpdate[] memory rateUpdates = rateStrategiesUpdates();
    IRiskSteward.PriceCapLstUpdate[] memory lstPriceCapUpdates = lstPriceCapsUpdates();
    IRiskSteward.PriceCapStableUpdate[] memory stablePriceCapUpdates = stablePriceCapsUpdates();

    bool rateUpdatesPresent = rateUpdates.length != 0;
    if (generateDiffReport) createConfigurationSnapshot(pre, POOL, true, rateUpdatesPresent, false, false);

    if (capUpdates.length != 0) {
      callDatas[txCount] = abi.encodeWithSelector(
        IRiskSteward.updateCaps.selector,
        capUpdates
      );
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (collateralUpdates.length != 0) {
      callDatas[txCount] = abi.encodeWithSelector(
        IRiskSteward.updateCollateralSide.selector,
        collateralUpdates
      );
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (rateUpdates.length != 0) {
      callDatas[txCount] = abi.encodeWithSelector(
        IRiskSteward.updateRates.selector,
        rateUpdates
      );
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (lstPriceCapUpdates.length != 0) {
      callDatas[txCount] = abi.encodeWithSelector(
        IRiskSteward.updateLstPriceCaps.selector,
        lstPriceCapUpdates
      );
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (stablePriceCapUpdates.length != 0) {
      callDatas[txCount] = abi.encodeWithSelector(
        IRiskSteward.updateStablePriceCaps.selector,
        stablePriceCapUpdates
      );
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (generateDiffReport) {
      createConfigurationSnapshot(post, POOL, true, rateUpdatesPresent, false, false);
      diffReports(pre, post);
    }

    // we defined the callDatas with MAX_TX size, we now squash it to the number of txs
    assembly {
      mstore(callDatas, txCount)
    }
    return callDatas;
  }

  function _sendToSafe(bytes memory callDatas) internal {
    string[] memory inputs = new string[](8);
    inputs[0] = 'npx';
    inputs[1] = 'ts-node';
    inputs[2] = 'scripts/safe-helper.ts';
    inputs[3] = vm.toString(STEWARD.RISK_COUNCIL());
    inputs[4] = vm.toString(address(STEWARD));
    inputs[5] = vm.toString(callDatas);
    inputs[6] = vm.toString(block.chainid);
    inputs[7] = 'Call';
    vm.ffi(inputs);
  }

  function _verifyCallResult(
    bool success,
    bytes memory returnData
  ) private pure returns (bytes memory) {
    if (success) {
      return returnData;
    } else {
      // Look for revert reason and bubble it up if present
      if (returnData.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returnData)
          revert(add(32, returnData), returndata_size)
        }
      } else {
        revert FailedUpdate();
      }
    }
  }
}
