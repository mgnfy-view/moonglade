# Base mainnet output

Confirmed transactions on **Base mainnet (8453)** using the deployed 1inch Aqua and Morpho Midnight contracts,
the custom Moonglade SwapVM router, and real USDC, WETH, and mgNOTE. No fork fixtures or time travel.

The four sections follow the presentation order: maker, lend, borrow, exit. Actual execution order was
**maker → lend → exit → borrow**. Amounts exclude gas paid in ETH. Setup and approvals are separate transactions.

| Role | Address |
| --- | --- |
| Maker | [0x51eb5C81066de005965Be0fA3958627B77005282](https://basescan.org/address/0x51eb5C81066de005965Be0fA3958627B77005282) |
| Lender / borrower | [0x90124003F9122abE3b3E06824d639A582fE913cB](https://basescan.org/address/0x90124003F9122abE3b3E06824d639A582fE913cB) |

Market: **USDC loans / WETH collateral**, maturing **25 December 2026, 15:00 UTC**. Maker fee: **30 bps (0.30%)**,
embedded in the USDC quote on both sides. Midnight's settlement fee was **zero** for these fills.

## 1. Maker strategy created

[Successful Aqua registration](https://basescan.org/tx/0x41d1b8b13b099b369e0c9bdbde6ce258b58de13763b4fb631b6a72a2072a2330)
at block **54,083,327**, following [desk configuration](https://basescan.org/tx/0x4ed7d0db65594bf70e119f1805febab47f97e8d3d75a603790da3f3533a2c525).

```text
Strategy hash               0xa83c5df1f7aed2f5fbbb749a99f256647d8c56f91d81e6612641f20bec525bc1
Virtual cash budget         10.000000 USDC
Virtual note budget         22.255409 mgNOTE
Pricing                     YieldSpace; 0.30% maker fee
```

The receipt's `Shipped` event identifies this maker, router, and strategy hash. Aqua's `Pushed` events record the
virtual budgets; shipping does not deposit tokens into a pool. The same strategy hash appears in all three swaps.

## 2. Lend on the AMM

[Successful lend](https://basescan.org/tx/0x4ad8fb40fe0fb439ffc71360c97f15d7b32900dbc0ce503af89c6fbe49604e5f)
at block **54,116,329** · **7 November 2026, 01:07:21 UTC**.

```text
Lender pays                 0.100000 USDC
Lender receives             0.100753 mgNOTE
Maker debt created          0.101753 USDC units
Initial dead-share reserve  0.001000 mgNOTE
Maker collateral posted     0.000066069039710943 WETH
Lender debt                 0.000000 USDC units
```

The hook minted the missing notes during settlement. This was the first mint, so **0.001000 mgNOTE** went to the
dead-share reserve and **0.100753 mgNOTE** went to the lender. Total supply and net credit both became **0.101753**.
The maker's temporary **0.100011 USDC** mint float returned to the maker; it was not an additional lender charge.

## 3. Borrow on the AMM

[Successful borrow](https://basescan.org/tx/0x8b8689edca1edcfb10f2a7d359b7b093f9c65f2e23d2964438b68f15f84a5110)
at block **54,118,781** · **7 November 2026, 01:15:31 UTC**.

```text
Borrower receives           0.100000 USDC
Notes sold                  0.101400 mgNOTE
Existing notes consumed     0.000003 mgNOTE
New notes minted            0.101397 mgNOTE
Borrower debt created       0.101397 USDC units
Borrower collateral posted  0.000098000000000000 WETH (already supplied before this swap)
Borrower notes remaining    0.000000 mgNOTE
```

The existing notes were dust left by the earlier exit. The hook minted only the shortfall under the borrower's
scoped approval. With no existing Midnight lender credit to consume, that shortfall became borrower debt.
The temporary **0.099998 USDC** mint float returned to the maker and was not an extra borrower payment.

At the transaction's oracle price, the collateral's value was **0.219376 USDC**. Applying the market's **86% LLTV**
gave **0.188663 USDC** of borrowing capacity. Debt of **0.101397 USDC** used **53.745%** of that capacity.

The maker also burned **0.001003 mgNOTE** from the incoming notes to cancel its remaining **0.001003 USDC debt**,
then released its remaining **0.000000651764925410 WETH** collateral. The borrower's debt stayed on the borrower's
own Midnight position.

## 4. Exit early on the AMM

[Successful exit](https://basescan.org/tx/0x2b99035044ec4fc310d1ea9c10abc245e84a8d14a0e4a6f03467499d1fd9110d)
at block **54,117,004** · **7 November 2026, 01:09:36 UTC**.

```text
Lender sells                0.100750 mgNOTE
Lender receives             0.099386 USDC
Lender notes remaining      0.000003 mgNOTE
Maker debt cancelled        0.100750 USDC units
Maker debt remaining        0.001003 USDC units
Maker collateral returned   0.000065417274785533 WETH
Lender debt                 0.000000 USDC units
```

The lender exited **135 seconds after lending**, before maturity. Purchased notes were burned to cancel maker
debt, and surplus maker collateral returned to its wallet. The **0.000614 USDC** cash difference from the original
lend reflects two-sided fees, tick rounding, inventory price impact, and the small note balance left unsold; it
excludes ETH gas. The later borrow consumed that remaining note balance.

## Math verification

Historical reads used the block before each swap for reserves and positions, and the actual transaction block's
timestamp for time to maturity. No earlier events from Aqua, Midnight, the router, hook, or note occurred in those
same blocks before these transactions. Independent 90-digit YieldSpace calculations matched the contract's native
quotes. Exact integer tick conversion, amount rounding, mint quantities, and maker collateral calculations matched
the receipts and resulting state.

| Fill | Curve quote including the maker fee | Grid tick | Grid price (USDC / mgNOTE) | Final amount |
| --- | --- | --- | --- | --- |
| Lend 0.100000 USDC | Receive 0.100758 mgNOTE | 4352 | 0.9925183 | Receive **0.100753 mgNOTE** |
| Borrow 0.100000 USDC | Sell 0.101385 mgNOTE | 4228 | 0.9862019 | Sell **0.101400 mgNOTE** |
| Exit 0.100750 mgNOTE | Receive 0.099393 USDC | 4232 | 0.9864707 | Receive **0.099386 USDC** |

```text
Lend shares   = floor(0.100000 / 0.9925183, 6 decimals) = 0.100753 mgNOTE
Borrow shares = ceil (0.100000 / 0.9862019, 6 decimals) = 0.101400 mgNOTE
Borrow debt   = 0.101400 - 0.000003                    = 0.101397 USDC units
Exit cash     = floor(0.100750 * 0.9864707, 6 decimals) = 0.099386 USDC
```

The maker fee is embedded in pricing; there is no separate fee-transfer event. Tick rounding adds spread beyond the
configured fee. The exact results above verify these fills, not future liquidity or redemption. Maturity redemption
and larger examples are demonstrated separately in the [fork output](output.txt).
