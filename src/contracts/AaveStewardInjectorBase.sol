// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IAaveStewardInjectorBase} from '../interfaces/IAaveStewardInjectorBase.sol';
import {AutomationCompatibleInterface} from './dependencies/AutomationCompatibleInterface.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @title AaveStewardInjectorBase
 * @author BGD Labs
 * @notice Base Injector contract to perform automation on risk steward using the edge risk oracle.
 * @dev Aave chainlink automation-keeper-compatible contract to:
 *      - check if updates from edge risk oracles can be injected into risk steward.
 *      - injects updates on the risk steward if all conditions are met.
 */
abstract contract AaveStewardInjectorBase is
  Ownable,
  AutomationCompatibleInterface,
  IAaveStewardInjectorBase
{
  /// @inheritdoc IAaveStewardInjectorBase
  address public immutable RISK_ORACLE;

  /// @inheritdoc IAaveStewardInjectorBase
  address public immutable RISK_STEWARD;

  /**
   * @inheritdoc IAaveStewardInjectorBase
   * @dev after an update is added on the risk oracle, the update is only valid from the timestamp it was added
   *      on the risk oracle plus the expiration time, after which the update cannot be injected into the risk steward.
   */
  uint256 public constant EXPIRATION_PERIOD = 6 hours;

  mapping(uint256 => bool) internal _isUpdateIdExecuted;
  mapping(uint256 => bool) internal _disabledUpdates;
  bool internal _isPaused;

  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param guardian address of the guardian / owner of the stewards injector.
   */
  constructor(address riskOracle, address riskSteward, address guardian) {
    RISK_ORACLE = riskOracle;
    RISK_STEWARD = riskSteward;
    _transferOwnership(guardian);
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev run off-chain, checks if the update from risk oracle should be injected on risk steward
   */
  function checkUpkeep(bytes memory) public view virtual returns (bool, bytes memory);

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev executes injection of update from the risk oracle into the risk steward.
   */
  function performUpkeep(bytes calldata) external virtual;

  /// @inheritdoc IAaveStewardInjectorBase
  function isDisabled(uint256 updateId) public view returns (bool) {
    return _disabledUpdates[updateId];
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function disableUpdateById(uint256 updateId, bool disabled) external onlyOwner {
    _disabledUpdates[updateId] = disabled;
    emit UpdateDisabled(updateId, disabled);
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function pauseInjector(bool isPaused) external onlyOwner {
    _isPaused = isPaused;
    emit InjectorPaused(isPaused);
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function isInjectorPaused() public view returns (bool) {
    return _isPaused;
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function isUpdateIdExecuted(uint256 updateId) public view returns (bool) {
    return _isUpdateIdExecuted[updateId];
  }
}
