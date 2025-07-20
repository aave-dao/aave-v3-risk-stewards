// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IAaveStewardInjectorBase} from '../interfaces/IAaveStewardInjectorBase.sol';
import {EnumerableSet} from 'openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {AutomationCompatibleInterface} from './dependencies/AutomationCompatibleInterface.sol';
import {OwnableWithGuardian} from 'solidity-utils/contracts/access-control/OwnableWithGuardian.sol';

/**
 * @title AaveStewardInjectorBase
 * @author BGD Labs
 * @notice Base Injector contract to perform automation on risk steward using the edge risk oracle.
 * @dev Aave chainlink automation-keeper-compatible contract to:
 *      - check if updates from edge risk oracles can be injected into risk steward.
 *      - injects updates on the risk steward if all conditions are met.
 */
abstract contract AaveStewardInjectorBase is
  OwnableWithGuardian,
  AutomationCompatibleInterface,
  IAaveStewardInjectorBase
{
  using Strings for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _markets;

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
   * @param markets list of market addresses to allow.
   * @param owner address of the owner of the stewards injector.
   * @param guardian address of the guardian of the stewards injector.
   */
  constructor(
    address riskOracle,
    address riskSteward,
    address[] memory markets,
    address owner,
    address guardian
  ) OwnableWithGuardian(owner, guardian) {
    RISK_ORACLE = riskOracle;
    RISK_STEWARD = riskSteward;

    _addMarkets(markets);
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev run off-chain, checks if the update from risk oracle should be injected on risk steward
   */
  function checkUpkeep(bytes memory) public view virtual returns (bool, bytes memory) {
    address[] memory markets = getMarkets();
    string[] memory updateTypes = getUpdateTypes();

    ActionData[] memory actions = new ActionData[](markets.length * updateTypes.length);
    uint256 actionCount;

    for (uint256 i = 0; i < markets.length; i++) {
      for (uint256 j = 0; j < updateTypes.length; j++) {
        address market = markets[i];
        string memory updateType = updateTypes[j];

        try
          IRiskOracle(RISK_ORACLE).getLatestUpdateByParameterAndMarket(updateType, market)
        returns (IRiskOracle.RiskParameterUpdate memory updateRiskParams) {
          if (_canUpdateBeInjected(updateRiskParams)) {
            actions[actionCount] = ActionData({market: market, updateType: updateType});
            actionCount++;
          }
        } catch {}
      }
    }

    if (actionCount > 0) return (true, abi.encode(_getRandomizedAction(actions, actionCount)));
    return (false, '');
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev executes injection of update from the risk oracle into the risk steward.
   */
  function performUpkeep(bytes calldata performData) external override {
    ActionData memory actionData = abi.decode(performData, (ActionData));

    IRiskOracle.RiskParameterUpdate memory updateRiskParams = IRiskOracle(RISK_ORACLE)
      .getLatestUpdateByParameterAndMarket(actionData.updateType, actionData.market);

    if (!_canUpdateBeInjected(updateRiskParams)) {
      revert UpdateCannotBeInjected();
    }

    _isUpdateIdExecuted[updateRiskParams.updateId] = true;
    _injectUpdate(updateRiskParams);

    emit ActionSucceeded(updateRiskParams.updateId);
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function isDisabled(uint256 updateId) public view returns (bool) {
    return _disabledUpdates[updateId];
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function disableUpdateById(uint256 updateId, bool disabled) external onlyOwnerOrGuardian {
    _disabledUpdates[updateId] = disabled;
    emit UpdateDisabled(updateId, disabled);
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function pauseInjector(bool isPaused) external onlyOwnerOrGuardian {
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

  /// @inheritdoc IAaveStewardInjectorBase
  function getMarkets() public view returns (address[] memory) {
    return _markets.values();
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function addMarkets(address[] calldata markets) external onlyOwner {
    _addMarkets(markets);
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function removeMarkets(address[] calldata markets) external onlyOwner {
    for (uint256 i = 0; i < markets.length; i++) {
      bool success = _markets.remove(markets[i]);
      if (success) emit MarketRemoved(markets[i]);
    }
  }

  /**
   * @notice method to check if the update from risk oracle could be injected into the risk steward.
   * @dev only allow injecting updates for the configured assets i.e market addresses.
   * @param updateRiskParams struct containing the risk param update from the risk oracle to check if it can be injected.
   * @return true if the update could be injected to the risk steward, false otherwise.
   */
  function _canUpdateBeInjected(
    IRiskOracle.RiskParameterUpdate memory updateRiskParams
  ) internal view returns (bool) {
    // validates if an update is not executed before
    if (isUpdateIdExecuted(updateRiskParams.updateId)) return false;

    // validates if an update is not expired
    if ((updateRiskParams.timestamp + EXPIRATION_PERIOD <= block.timestamp)) return false;

    // validates if the market is allowed
    if (!_markets.contains(updateRiskParams.market)) return false;

    // validates if the updateId is not disabled or the injector is not paused
    if (isDisabled(updateRiskParams.updateId) || isInjectorPaused()) return false;

    // validates that the update has a valid update type
    string[] memory updateTypes = getUpdateTypes();
    for (uint256 i = 0; i < updateTypes.length; i++) {
      if (updateRiskParams.updateType.equal(updateTypes[i])) return true;
    }

    return false;
  }

  /**
   * @notice method to select a randomized action from a list of actions.
   * @param actions the list of actions from where we select a randomized action.
   * @param actionCount the count of actions.
   * @return action the randomized action from the actions list.
   */
  function _getRandomizedAction(
    ActionData[] memory actions,
    uint256 actionCount
  ) internal view returns (ActionData memory action) {
    uint256 randomNumber = uint256(
      keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))
    );
    action = actions[randomNumber % actionCount];
  }

  /**
   * @notice method called to whitelist markets on the injector.
   * @param markets array of addresses to whitelist.
   */
  function _addMarkets(address[] memory markets) internal {
    for (uint256 i = 0; i < markets.length; i++) {
      bool success = _markets.add(markets[i]);
      if (success) emit MarketAdded(markets[i]);
    }
  }

  /// @inheritdoc IAaveStewardInjectorBase
  function getUpdateTypes() public view virtual returns (string[] memory);

  /**
   * @notice method to repack update from risk oracle and inject into the protocol.
   * @param updateRiskParams struct containing the risk param update from the risk oracle.
   */
  function _injectUpdate(IRiskOracle.RiskParameterUpdate memory updateRiskParams) internal virtual;
}
