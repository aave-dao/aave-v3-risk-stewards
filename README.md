# Aave Risk Stewards Phase 2

Expanding from the scope of from CapsPlusRiskSteward, we now introduce the new RiskSteward, allowing hardly constrained risk parameter updates by risk service providers and reducing governance overhead.

## Specification

The new RiskSteward we propose follows the same design as the CapsPlusRiskSteward: a smart contract to which the Aave Governance gives `POOL_ADMIN` the role over all v3 instances, controlled by a 2-of-2 multi-sig of the risk providers, and heavily constrained on what can do and how by its own logic.

_Note: The Risk Stewards 2 will only be available for Aave V3 instances and not Aave V2 due to missing admin roles on Aave V2 instances._

The following risk params could be changed by the RiskStewards:

- Supply Caps
- Borrow Caps

- LTV
- Liquidation Threshold
- Liquidation Bonus
- Debt Ceiling

- Base variable borrow rate
- Slope 1
- Slope 2
- Optimal point

#### Min Delay:

For each risk param, `minDelay` can be configured, which is the minimum amount of delay (denominated in seconds) required before pushing another update for the risk param. Please note that this is specific for a risk param and includes both in upwards and downwards direction. Ex. after increasing LTV by 5%, we must wait by `minDelay` before either increasing it again or decreasing it.

#### Max Percent Change:

For each risk param, `maxPercentChange` which is the maximum percent change allowed (both upwards and downwards) for the risk param using the RiskStewards.

- Supply cap, Borrow cap and Debt ceiling: The `maxPercentChange` is relative and is denominated in BPS. (Ex. `50_00` for 50% increase / decrease)
- LTV, LT, LB: The `maxPercentChange` is in absolute values and is also denominated in BPS. (Ex. `5_00` for +-5% change in LTV)
- Interest rates params: For Base Variable Borrow Rate, Slope 1, Slope 2, Optimal Point the `maxPercentChange` is in absolute values and is denominated in ray. (Ex. `_bpsToRay(10_00)` for +- 10% change in uOptimal)

After the activation proposal, these params could only be changed by the governance by calling the `setRiskConfig()` method.

_Note: The Risk Stewards will not allow setting the values to 0 for supply cap, borrow cap, debt ceiling, LTV, Liquidation Threshold, Liquidation Bonus no matter if the maxPercentChange has been configured to 100%. The Risk Stewards will however allow setting the value to 0 for interest rate param updates._

#### Restricted Assets:

Some assets can also be restricted on the RiskStewards by calling the `setAssetRestricted()` method. This prevents the RiskStewards to make any updates on the specific asset. One example of the restricted asset could be GHO.

### Setup

```sh
cp .env.example .env
forge install
```

### Test

```sh
forge test
```

## Copyright

2024 BGD Labs
