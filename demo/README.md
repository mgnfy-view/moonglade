# Moonglade demo

[View verified output](output.txt), or run from the repository root:

```bash
forge soldeer install  # First run only.
forge build           # First run only.
bash demo/run.sh
```

The runner calls `showConfig()` once before printing scene results.

Run one scene with `bash demo/run.sh <scene>`:

| Scene | Demonstrates |
| --- | --- |
| `maker` | Aqua registration; funds stay in the maker wallet |
| `lend` | USDC → mgNOTE with inventory minted on demand |
| `sell` | mgNOTE → USDC; maker debt and collateral decrease |
| `borrow` | Collateralized USDC borrowing in one swap |
| `maturity` | Debt repayment and USDC redemption |
| `shared` | Two Aqua strategies using one maker wallet |

Base fork at block `52000000`, using official Aqua/Midnight and forked USDC/WETH. Each scene starts fresh. Moonglade deploys locally; funding, governance impersonation, the fixed $2,000/WETH oracle, and time travel are fixtures. Nothing is broadcast.
