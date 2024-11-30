// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPayloadsControllerCore, PayloadsControllerUtils} from 'aave-address-book/governance-v3/IPayloadsControllerCore.sol';
import {Executor} from '../dependencies/Executor.sol';
import {TransparentProxyFactory} from 'solidity-utils/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {PermissionedPayloadsController} from '../dependencies/PermissionedPayloadsController.sol';
import {ProxyAdmin} from 'solidity-utils/contracts/transparent-proxy/ProxyAdmin.sol';
import {RiskSteward} from '../RiskSteward.sol';

import {IAaveV3ConfigEngine as IEngine, IPool} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IRiskSteward} from '../../interfaces/IRiskSteward.sol';
import {ProtocolV3TestBase} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {IOwnable} from 'aave-address-book/common/IOwnable.sol';
import {IACLManager} from 'aave-address-book/AaveV3.sol';

abstract contract RiskStewardsBase is ProtocolV3TestBase {
  error FailedUpdate();
  IPool immutable POOL;
  IRiskSteward STEWARD; // TODO: make immutable once deployed
  IPayloadsControllerCore PAYLOADS_CONTROLLER; // TODO: make immutable once deployed
  address public constant PAYLOADS_MANAGER = address(490); // TOOD: remove once contracts are deployed

  uint8 public constant MAX_TX = 5;

  // TODO: remove once deployed
  function setUp() public virtual {
    _setupPermissionedPayloadsController();
  }

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
  function test_run() external {
    bool generateDiffReport = vm.envBool('GENERATE_DIFF');

    _simulateAndGenerateDiff(generateDiffReport);
  }

  function _simulateAndGenerateDiff(bool generateDiffReport) internal {
    string memory pre = string(abi.encodePacked('pre_', name()));
    string memory post = string(abi.encodePacked('post_', name()));

    vm.prank(PAYLOADS_MANAGER);
    uint40 payloadId = PAYLOADS_CONTROLLER.createPayload(buildActions());

    vm.warp(block.timestamp + 1 days + 1);

    if (generateDiffReport) createConfigurationSnapshot(pre, POOL, true, true, false, false);

    PAYLOADS_CONTROLLER.executePayload(payloadId);

    if (generateDiffReport) {
      createConfigurationSnapshot(post, POOL, true, true, false, false);
      diffReports(pre, post);
    }
  }

  function buildActions() public view returns (IPayloadsControllerCore.ExecutionAction[] memory) {
    IPayloadsControllerCore.ExecutionAction[]
      memory actions = new IPayloadsControllerCore.ExecutionAction[](MAX_TX);
    uint256 actionsCount;

    IEngine.CapsUpdate[] memory capUpdates = capsUpdates();
    IEngine.CollateralUpdate[] memory collateralUpdates = collateralsUpdates();
    IEngine.RateStrategyUpdate[] memory rateUpdates = rateStrategiesUpdates();
    IRiskSteward.PriceCapLstUpdate[] memory lstPriceCapUpdates = lstPriceCapsUpdates();
    IRiskSteward.PriceCapStableUpdate[] memory stablePriceCapUpdates = stablePriceCapsUpdates();

    if (capUpdates.length != 0) {
      actions[actionsCount].target = address(STEWARD);
      actions[actionsCount].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
      actions[actionsCount].callData = abi.encodeWithSelector(
        IRiskSteward.updateCaps.selector,
        capUpdates
      );
      actionsCount++;
    }

    if (collateralUpdates.length != 0) {
      actions[actionsCount].target = address(STEWARD);
      actions[actionsCount].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
      actions[actionsCount].callData = abi.encodeWithSelector(
        IRiskSteward.updateCollateralSide.selector,
        collateralUpdates
      );
      actionsCount++;
    }

    if (rateUpdates.length != 0) {
      actions[actionsCount].target = address(STEWARD);
      actions[actionsCount].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
      actions[actionsCount].callData = abi.encodeWithSelector(
        IRiskSteward.updateRates.selector,
        rateUpdates
      );
      actionsCount++;
    }

    if (lstPriceCapUpdates.length != 0) {
      actions[actionsCount].target = address(STEWARD);
      actions[actionsCount].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
      actions[actionsCount].callData = abi.encodeWithSelector(
        IRiskSteward.updateLstPriceCaps.selector,
        lstPriceCapUpdates
      );
      actionsCount++;
    }

    if (stablePriceCapUpdates.length != 0) {
      actions[actionsCount].target = address(STEWARD);
      actions[actionsCount].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
      actions[actionsCount].callData = abi.encodeWithSelector(
        IRiskSteward.updateStablePriceCaps.selector,
        stablePriceCapUpdates
      );
      actionsCount++;
    }

    // we defined the actions with MAX_TX size, we now squash it to the number of txs
    assembly {
      mstore(actions, actionsCount)
    }

    return actions;
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

  function _setupPermissionedPayloadsController() internal {
    Executor executor = new Executor();
    address payloadsControllerImpl = address(new PermissionedPayloadsController());

    IPayloadsControllerCore.UpdateExecutorInput[]
      memory executorInput = new IPayloadsControllerCore.UpdateExecutorInput[](1);
    executorInput[0].accessLevel = PayloadsControllerUtils.AccessControl.Level_1;
    executorInput[0].executorConfig.executor = address(executor);
    executorInput[0].executorConfig.delay = 1 days;

    TransparentProxyFactory proxyFactory = new TransparentProxyFactory();
    PAYLOADS_CONTROLLER = IPayloadsControllerCore(
      proxyFactory.create(
        address(payloadsControllerImpl),
        ProxyAdmin(address(728)),
        abi.encodeWithSelector(
          PermissionedPayloadsController.initialize.selector,
          address(659),
          PAYLOADS_MANAGER,
          executorInput
        )
      )
    );
    executor.transferOwnership(address(PAYLOADS_CONTROLLER));

    STEWARD = new RiskSteward(
      STEWARD.POOL_DATA_PROVIDER(),
      STEWARD.CONFIG_ENGINE(),
      address(executor),
      STEWARD.getRiskConfig()
    );
    address aclManager = STEWARD.POOL_DATA_PROVIDER().ADDRESSES_PROVIDER().getACLManager();
    vm.prank(STEWARD.POOL_DATA_PROVIDER().ADDRESSES_PROVIDER().getACLAdmin());
    IACLManager(aclManager).addRiskAdmin(address(STEWARD));
  }
}
