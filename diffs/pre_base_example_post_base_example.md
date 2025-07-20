## Reserve changes

### Reserve altered

#### WETH ([0x4200000000000000000000000000000000000006](https://basescan.org/address/0x4200000000000000000000000000000000000006))

| description | value before | value after |
| --- | --- | --- |
| liquidationThreshold | 83 % [8300] | 84 % [8400] |


#### USDC ([0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913](https://basescan.org/address/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913))

| description | value before | value after |
| --- | --- | --- |
| ltv | 75 % [7500] | 77 % [7700] |
| liquidationThreshold | 78 % [7800] | 79 % [7900] |
| liquidationBonus | 5 % | 6 % |


## Raw diff

```json
{
  "reserves": {
    "0x4200000000000000000000000000000000000006": {
      "liquidationThreshold": {
        "from": 8300,
        "to": 8400
      }
    },
    "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913": {
      "liquidationBonus": {
        "from": 10500,
        "to": 10600
      },
      "liquidationThreshold": {
        "from": 7800,
        "to": 7900
      },
      "ltv": {
        "from": 7500,
        "to": 7700
      }
    }
  }
}
```