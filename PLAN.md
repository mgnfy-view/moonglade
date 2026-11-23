# Frontend overhaul

Status: open working plan. Use this document to agree on the experience, divide work, and record decisions as implementation progresses. Routes, component boundaries, and visual layouts below are proposals, not a locked specification.

The goal is a polished product that an investor can understand quickly and use without a walkthrough: lend, borrow, redeem, or operate a fixed-rate desk. Keep the Swiss / Neo Swiss identity; improve clarity, execution, and completeness.

## Start here

1. Read the [product README](README.md), [whitepaper](docs/Moonglade-Whitepaper.pdf), and [web setup](apps/web/README.md).
2. Work from `dev`. The development site is [moonglade-web.vercel.app](https://moonglade-web.vercel.app/). `main` and its ETHGlobal submission deployment stay preserved.
3. Agree on the navigation, one representative trade screen, and one maker dashboard screen before redesigning every page.
4. Prove dynamic discovery, maker setup, and redemption against the existing contracts before presenting those flows as finished.
5. Build one complete investor journey through the sandbox, then expand to the other journeys.

```bash
pnpm install --frozen-lockfile
pnpm dev
pnpm build:web
```

## Boundaries

- **No protocol contract changes.** Keep deployed behavior, Solidity interfaces, permissions, fees, pricing, and risk enforcement intact. No new registry, helper contract, paymaster, or replacement protocol implementation.
- New desks may require deploying an **unchanged existing hook**, and new eligible markets may require calling the existing note factory. These are uses of the current protocol, not permission to change its code. Surface deployment gas and transactions explicitly; this plan does not authorize live deployments.
- Start with Base and support its eligible Midnight markets dynamically. “Any active market” means any market supported by the existing contracts: ungated, on the configured chain and Midnight deployment, compatible token behavior, usable collateral/oracles, and outside the trading cutoff. Explain exclusions instead of silently promising universal compatibility.
- Keep the React / TypeScript / Vite, RainbowKit, wagmi, viem, and TanStack Query foundation. Use the pnpm workspace; avoid a framework migration as part of the redesign.
- The web app can remain client-side. Reliable indexing and an always-on investor fork may need separate services. Introduce those only where they solve a concrete need; hosting/provider spend needs a separate decision.

## What exists today

| Area | Current starting point | Work required |
| --- | --- | --- |
| Landing | Swiss-style page, brand typography, moon/reflection artwork | Refine hierarchy and simplify the pitch |
| Directory | One hardcoded maker in `apps/web/src/lib/makers.ts` | Discover and validate desks dynamically |
| Trading | Working lend / borrow / sell transactions | Generalize beyond the fixed USDC/WETH desk; polish the full journey |
| Integration | `protocol.ts`, `contracts.ts`, and `useMoonglade.ts` assume one desk/market | Pass explicit network, market, note, and desk context throughout |
| Maker setup | Foundry deployment/configuration scripts | Translate existing calls into a resumable wallet-driven dashboard |
| Redemption | Existing `MoongladeNote.redeem(shares, receiver)` | Add maturity-aware UI, preview, liquidity checks, and receipt handling |
| Demo | Fork scripts and recorded mainnet transactions | Explore a persistent, interactive investor sandbox |

The maker is an address; **Moonglade is the protocol**, not the maker's name. Multiple desks can belong to the same maker. Multiple desks can also trade the same market-specific note.

## 1. Design direction and assets

Use an editorial grid, deliberate whitespace, strong alignment, restrained color, and clear typography. Professional should mean quieter and easier to read, not more panels, gradients, or ornament.

- Preserve the **Moonglade** lettermark. Do not attach a moon logo to it. Moon artwork can remain an illustration or favicon.
- Keep Switzer at its supplied weights. Avoid synthetic bold, text scaling/transforms, decorative filters, and aggressive tracking. Test rendering on ordinary laptops and phones.
- Establish spacing, type, surface, border, focus, and interaction tokens before accumulating page-specific CSS. The palette in [docs/brand/moonglade.gpl](docs/brand/moonglade.gpl) is the color authority.
- Use light and dark compositions intentionally, with consistent hierarchy across marketing and application screens. Keep the blue moon/reflection artwork where it supports the layout.
- Use icons to help scanning and indicate actions. Remove duplicate labels, tiny captions, and unexplained badges. Reveal technical details on demand.

| Brand role | Existing color |
| --- | --- |
| Midnight | `#080156` |
| Primary accent | `#4030de` |
| Mist | `#f2f1f9` |
| Light border | `#d3d0ee` |
| Supporting lavender | `#8e86e0` |

### Custom token PNGs

Replace generic placeholders with a coherent set of high-quality PNG assets. This is a required part of the overhaul.

- Create a distinctive mgNOTE asset using the brand's geometric language. Loan and collateral tokens should stay recognizable; do not recolor every asset into an indistinguishable Moonglade coin.
- Cover the initial demo set first: mgNOTE, USDC, WETH, and WBTC if used. Use licensed official token artwork as source where appropriate; retain required attribution.
- Supply transparent square PNGs at consistent sizes, such as 64, 128, and 256 pixels. Check clarity at the actual small UI sizes on both light and dark backgrounds.
- Proposed location: `apps/web/public/tokens/`, with a manifest keyed by network and token address. Never identify an asset by symbol alone. Note badges can add the loan asset and maturity without implying separate note contracts for each desk.
- Unknown assets get a deliberate, legible fallback; broken or untrusted remote image URLs must not degrade the screen. Load packaged artwork first for supported tokens.

Deliver a small visual reference covering buttons, inputs, tables, tabs, dialogs, token pairs, charts, loading states, and error states. Avoid making a separate design-system package until another app actually needs it.

## 2. Landing page: explain the product before the architecture

Within the first screen, a visitor should understand what Moonglade does, who it serves, and how to try it. Lead with fixed-rate credit; explain Aqua, SwapVM, and Midnight after the benefit is clear.

Suggested story, open to better copy and layouts:

1. **Hero:** retain “Fixed-rate credit. One swap away.” Pair it with one short explanation and a primary “Try the demo” action; offer “Open app” as the live-market path. Do not imply the protocol only supports WETH or USDC.
2. **Two user flows:** show lending as loan token → mgNOTE → redeem at maturity, and borrowing as collateral → loan token now → repayment later. Show early sale as a separate optional branch. A compact diagram or interactive amount example can replace paragraphs.
3. **Maker value:** create a desk, choose pricing and limits, earn from trades using wallet-held liquidity. Keep the three useful ideas: automated quotes, inventory created during settlement, and shared wallet capital.
4. **Proof:** show the second-place 1inch Aqua track result and link to the real mainnet flows recorded in the README. Distinguish historical evidence from current balances, activity, or performance.
5. **Depth on demand:** integration strip, short mechanism explanation, whitepaper, source, and concise FAQ. An investor should be able to understand the page without learning ticks, opcodes, or credit-unit accounting.

Copy rules:

- Short sentences, concrete verbs, one idea per paragraph. Avoid repeating the headline or explaining every label.
- Distinguish the quoted rate from the final execution rate after fees and rounding. Never imply guaranteed returns or zero risk.
- “One swap” describes settlement after required approvals/collateral setup. Do not hide those steps from first-time borrowers.
- Early exit is a sale at the available quote, subject to liquidity and the existing cutoff. It is not a guaranteed redemption at par or available until the final second before maturity.
- “Nothing to pre-mint” is more precise than implying a maker needs no capital. Cash float, collateral, allowances, and risk limits still constrain execution.

Useful investor-demo additions: an optional short guided tour, a clear “why use this instead of waiting for an order-book match?” explanation, and an end-to-end example showing where assets sit. Keep unsupported market-size or revenue claims out of the product.

## 3. Navigation and user journeys

Recommended top-level navigation: **Markets · Portfolio · Make markets**, plus wallet and an explicit environment indicator. Visitors can browse before connecting. Start with these responsibilities; route names can change.

| Surface | Main job |
| --- | --- |
| `/` | Explain the product and start a demo or live journey |
| `/markets` | Discover markets and compare executable desk quotes |
| `/desks/:deskId` | Market context, maker address, and Lend / Borrow / Sell / Redeem tabs |
| `/portfolio` | Notes, borrowing positions, collateral, and available next actions |
| `/maker` | Connected maker's desks and aggregate exposure |
| `/maker/new` | Guided desk creation |
| `/maker/desks/:hookAddress` | Configuration, activity, exposure, and retirement |

Use stable desk identity based on environment/network and hook address; use the strategy hash to identify a configuration version. Deep links should survive a fee change. Distinguish market count, maker count, and desk count.

### Lenders and borrowers

- Let people choose a loan asset and maturity before comparing desks. Compare actual quotes for their amount, not only marginal curve rates. Preserve an intentional manual desk choice; automatic routing can remain a later improvement.
- Lead with “You pay / You receive,” maturity, execution rate, fee, and minimum received or maximum spent. Put unit/tick details behind an expandable breakdown.
- Borrowers need collateral already supplied or a guided supply step, projected debt, liquidation headroom, permission scope, and an expiring borrow limit. Show when existing notes or credit reduce newly originated debt.
- Sell means exchanging notes through a live desk; redeem means withdrawing their share of repaid credit after maturity. Preserve both paths and explain which one is currently usable.
- Portfolio should group holdings by note/market rather than the desk where they were bought. Borrower debt belongs to the wallet's Midnight market position, not a note balance.

Use a visible action sequence for approvals, collateral, authorizations, and settlement. Display signature requests, submitted transactions, confirmed results, and recoverable failures separately. Do not label a request successful before its receipt confirms.

### UX quality across all screens

Support mobile layouts, readable tables, equal-width action tabs, keyboard navigation, visible focus, accessible dialog behavior, reduced motion, and inline validation. Include empty, loading, stale-data, wrong-network, disconnected, rejected-signature, insufficient-funds, and unavailable-liquidity states in the design, not as an afterthought.

## 4. Integration foundation: remove the single-desk assumption

Do this before duplicating the current swap component across new routes.

- Separate network/deployment configuration from market data and desk data. Keep shared canonical contracts configured; derive note, hook, maker, tokens, collateral selection, and curve from validated chain state.
- Pass the selected context into snapshot reads, quote requests, balance/allowance reads, transaction construction, errors, and completion receipts. Remove fixed USDC/WETH labels, six-decimal assumptions, collateral index `0`, and global note/hook assumptions.
- Use bigint math for transaction amounts and protocol constraints. Read token decimals and metadata; unknown metadata must not silently become USDC. Choose and label a consistent rate convention before comparing annualized rates.
- Scope query keys to environment, chain, fork instance where applicable, account, market, hook, and strategy version. Invalidate affected views after receipts and discard responses from a previous selection or network.
- Load financially related reads at a consistent block, preserve quote expiry/slippage checks, and simulate writes for the actual signer. A discovered desk is not necessarily executable at the requested amount.

Keep shared integration types and helpers in the web app initially. Extract a `packages/sdk` only if the indexer or sandbox service needs the same encoding/validation logic; do not duplicate those rules across services.

## 5. Dynamic markets and desk discovery

Market discovery and desk discovery are different jobs. A Midnight market can exist with no Moonglade note or active desk.

### Markets

Use Morpho's market API as an indexed starting point, with explicit market-ID lookup as a fallback for unlisted markets. Resolve and verify configuration against the configured Midnight contract, including maturity, gates, tokens, collateral, and oracle policy. Do not drop an existing holding because its matured market disappears from an API listing.

The public API is evolving; isolate it behind an adapter and cache metadata. On a fork, use the fork's market registry/state rather than treating the live API as the source of fork-local markets. [Morpho market data documentation](https://docs.morpho.org/developers/midnight/tutorials/get-data/)

### Desks, without adding a registry contract

Recommended starting source: existing Aqua `Shipped` / `Docked` events plus live validation. `Shipped` includes the maker, app, strategy hash, and encoded order, so it provides candidates without a new onchain registry.

1. Read bounded block ranges from a configured deployment start block. The pinned Aqua event fields are not indexed; do not assume the RPC can filter by app/maker topics. Filter decoded results for the configured Moonglade router.
2. Decode supported order traits, hook targets, and program versions defensively. Resolve the hook, note, market, and curve from those candidates.
3. Validate the hook implementation/version and its maker, router, Aqua, Midnight, canonical note registration, order/hash, active state, and registration. A getter-compatible address is not sufficient proof of an official implementation. Keep custom curves distinguishable from the bundled YieldSpace implementation.
4. Fold docking/reconfiguration history into current status, recheck current chain state, and deduplicate by hook plus strategy version. Track confirmations, checkpoints, reorg recovery, and indexing freshness.
5. Return paginated/searchable results with explicit loading and stale states. A maker creating and shipping another desk must appear without a frontend code change.

For a small dataset, a browser log scan can prove the approach. If RPC limits or startup latency hurt UX, move the same pipeline into a small offchain indexer/cache with a cursor; do not make every visitor rescan all Aqua history. The chain remains the authority for transaction eligibility.

An unshipped draft hook has no Aqua registration event. Recover drafts from the transaction journal and permit explicit hook-address import; a small offchain draft record is optional. Do not pretend factory note events enumerate maker hooks.

## 6. Maker dashboard

The dashboard is an operational product, not just a settings form. Makers need to see what is live, what they owe, what can fill, and how to stop safely.

### Create a desk

Suggested wizard:

1. **Market:** select an eligible Midnight market, inspect loan token, collateral options, maturity, and gates. Resolve an existing canonical note or create it through the existing factory.
2. **Pricing:** start with the existing YieldSpace curve. Set sensitivity, rate floor, maker fee, and virtual loan/note budgets. Preview an initial quote and small buy/sell examples. Expose a custom curve address/settings only as an advanced path for existing deployed implementations.
3. **Risk and funding:** choose collateral index, maximum debt, maximum posted collateral, target utilization, maximum mint float, maximum burn cost, and auto-burn policy. Show required wallet balances and bounded token allowances separately from virtual budgets.
4. **Review and deploy:** reuse shared factory/router/curve deployments; deploy the unchanged `MoongladeDeskHook(maker, note, router)` for this desk. Use build-produced artifacts with traceable compiler/version metadata rather than hand-maintained bytecode.
5. **Authorize and activate:** reproduce the existing configuration script's permission, approval, `configure`, and direct maker `Aqua.ship` calls. Read `hook.order()` for shipping instead of reimplementing the program encoder in the browser. The maker must be the caller of `ship`.

The sequence is multiple transactions for an ordinary wallet. Save public progress and transaction hashes, resume from actual chain state, detect concurrent note creation, and skip only steps already satisfied. If a user stops before shipping, show “configured, not registered,” not “live.” Do not persist signing secrets in the setup journal.

### Manage and track

| Information | Presentation rule |
| --- | --- |
| Status | Derived from hook activation, Aqua registration, trading cutoff, maturity, and funding readiness |
| Pricing | Current curve, fee, marginal rate, actual size-dependent quotes, and configuration version |
| Budgets | Virtual Aqua allocations, clearly separate from wallet funds |
| Exposure | Wallet cash, note inventory, debt, collateral, utilization, and permission/allowance readiness |
| Activity | Confirmed fills, setup/configuration changes, pauses, and repayments with transaction links |
| Earnings | Fee/spread estimates with methodology; do not call volume, cash inflows, or all wallet profit “fees earned” |

Current fees are embedded in execution prices, not paid into a separate claimable fee pot. Separate fees from tick spread, carry, settlement costs, gas, and unrealized inventory value. If history cannot support an accurate earnings figure, show a qualified estimate or omit it.

Multiple desks in the **same maker wallet and Midnight market share debt, credit, and collateral**. Risk checks see that shared position. Do not sum the same position once per desk, present risk caps as isolated capital allocations, or promise isolated per-desk P&L. Different markets still share wallet token balances and allowances.

### Configure, pause, resume, and unwind

- **Change settings:** deactivate and dock the old strategy, call `configure` with revised parameters, then ship the new order/budgets. Existing code rejects configuration while active or registered. Show downtime and preserve historical strategy hashes.
- **Pause:** disabling the hook stops its callbacks; docking separately removes Aqua allocations. Reflect both states. A paused desk still has debt, collateral, note inventory, and permissions.
- **Resume:** verify both flags, rebuild the appropriate registration/configuration sequence from current state, revalidate funding, and never blindly replay prior transactions.
- **Unwind:** stop quoting, inspect the shared market position, repay through Midnight or use the existing note `burnToRepay` path when appropriate, then withdraw only collateral permitted by the resulting position. There is no hook `windDown`, `rebalance`, or `repayDebt` method to call.
- **Finish:** report residual debt, note inventory, credit, collateral, and remaining approvals. Do not revoke a ratifier or shared token allowance still needed by another desk. Midnight authorization is not scoped to one desk.

An unwind is a guided sequence, not guaranteed one-click liquidation. Price, cash, inventory, maturity, and other desks can affect what is possible. Direct repayment pays the debt units due; do not promise a prorated early-interest refund.

## 7. Redeem at maturity

Add a **Redeem** tab alongside Lend / Borrow / Sell, and expose it from Portfolio even if the originating desk is paused, replaced, or gone. Redeeming a note does not require an active AMM desk.

The existing call is `note.redeem(shares, receiver)`. It burns caller-owned **mgNOTE shares**, computes their proportional claim using updated Midnight credit and total share supply, and withdraws the loan token. Users should not be asked to enter internal credit units or assume one share always equals one unit/token.

Requirements:

- Read maturity and use chain time. Before maturity, show when redemption opens. Trading/new desk configuration currently stop **one day before maturity**, so the UI must represent the gap between trading closure and redemption opening.
- Preview using current note backing/supply and simulate the actual redeem call. The contract has no `previewRedeem` or `minAssets` argument; `previewBurn` concerns debt cancellation and is not a redemption quote. Do not promise onchain minimum-output protection that this method lacks.
- Show the loan asset actually returned, the recipient, note balance, and expected proceeds. Read decimals dynamically. Block accidental burns that round to zero proceeds unless the user explicitly chooses dust cleanup.
- Maturity does not imply immediate withdrawability. Check Midnight's withdrawable liquidity and simulation result. Offer a smaller redemption when executable, or a clear waiting state; never burn shares in a separate preliminary transaction.
- No ERC-20 approval is needed for the user's direct redeem call. Wait for the receipt, inspect `Redeemed`/token transfers, and refresh holdings and liquidity.

Do not advertise “100 USDC guaranteed at maturity.” Fees, losses, repayment/liquidity availability, and share conversion affect the claim.

## 8. Investor sandbox: explore, then implement behind a clear boundary

Recommended direction: the same web experience on a separate **Demo** environment, backed by a persistent Base Anvil fork and a narrowly scoped funding service. Keep the real Base path available separately. This adds infrastructure; it is not achievable as a purely static faucet inside the frontend.

First prove a vertical slice locally: enter as a guest, receive demo assets, lend, view a position, sell part of it, borrow against collateral, and redeem a matured position. No protocol bytecode changes are needed for this exploration.

### Proposed architecture

```text
Vercel frontend ── read RPC / signed transactions ── restricted HTTPS gateway ── Anvil
       │
       └── request demo funding ── funding/session service ── private admin RPC

Operator tools ── seed, inspect, reset, advance isolated scenarios ── private admin RPC
```

- Run Anvil on an always-on host/container with a pinned fork block, upstream archive-capable RPC, persistent state, health checks, restart policy, and bounded resources. Vercel continues serving the frontend; its request-duration-limited Functions are not the host for the persistent node. [Anvil capabilities](https://getfoundry.sh/anvil/overview) · [Vercel Function limits](https://vercel.com/docs/functions/limitations)
- Keep administrative methods private: impersonation, balance/storage mutation, snapshots, reset, time changes, unlocked-account signing, and node management. Public access should permit only required reads and signed transaction submission, with limits on batch size and expensive calls. CORS alone is not access control.
- Publish an environment manifest with chain ID, fork block, contract addresses, instance/reset ID, and scenario time. App state and the indexer must share this identity; a reset must invalidate old balances, transaction journals, receipts, and caches.
- Show a persistent, restrained “Demo · simulated funds” indicator. Use an in-app receipt/activity view for fork transactions; they will not exist on BaseScan.

### Network identity is an early feasibility gate

Prefer a unique demo chain ID to avoid confusing it with Base. However, Midnight market identity includes chain data, and both Midnight market initialization and the note factory validate chain ID. Do not change Anvil's chain ID and assume existing Base market creation/setup flows still work.

Spike a unique-ID fork with fork-local markets initialized on the **existing official Midnight contract**, using unchanged protocol code and eligible collateral parameters. Record which original Base positions are reused and which markets/notes are local fixtures. If that cannot support the required experience, document the alternative and signing/replay risks before choosing a Base-ID fork. This choice must precede wallet onboarding work. [Anvil fork and chain options](https://getfoundry.sh/anvil/reference/)

### Funding: one action, useful assets

The button can say **Get demo funds**, not expose a list of developer RPC operations.

- Supply gas, the selected loan asset, and usable collateral. USDC/gas alone cannot demonstrate a WETH-backed borrow; include wrapped collateral or an easy wrap step.
- Use a funded demo treasury and ordinary token transfers after private bootstrap. If bootstrap uses impersonation or storage funding, keep it fork-only, documented, and outside the investor's signing flow. Verify the real token contracts' balances and transfers.
- Make grants configurable and sufficient for the displayed scenarios. Rate-limit by session/address and serialize treasury nonces. Neither token quantities nor hosting budgets are fixed by this plan.
- Do not accept arbitrary target contracts, calldata, RPC methods, or recipient lists through the funding API. Keep service credentials and admin RPC URLs out of `VITE_*` variables and bundles.

### Optional wallet on entry

Keep **Connect wallet** for normal users. For the demo, explore **Try without a wallet** using a fresh temporary browser account and a viem wallet client. Viem supports local account generation/signing without requiring a new protocol contract. [Local account documentation](https://viem.sh/docs/accounts/local/privateKeyToAccount)

Use a distinct sandbox signer/connector path with an explicit environment guard; do not silently replace RainbowKit's connected account. Default to in-memory keys, make reload/session loss understandable, never transmit keys to the service, and never encourage depositing real assets. Any persisted-key/recovery design needs a separate security decision. Keep guest signing confined to the verified sandbox endpoint; provide a real-wallet path for durable accounts.

A managed embedded-wallet provider is an alternative if cross-device recovery becomes necessary. Evaluate its cost, account recovery, data handling, and integration effort before adding it; it is not required for the first demo.

### Time, concurrency, and reset behavior

- Pin and seed a reproducible fork state. An always-on node still ages toward maturity; define a reseed/rotation policy rather than allowing all desks to silently expire.
- Seed both a tradable market and a separate already-matured, repaid note position for the investor's redemption flow. A server-funded demo note holder can transfer shares to the guest. Advancing time alone does not repay loans.
- Never let one visitor advance the global clock or reset a shared fork while others transact. Use a separate operator-controlled maturity instance or per-session forks if an accelerated full lifecycle is important.
- Shared forks are simpler and cheaper, but visitors affect common inventory/prices. Start with bounded grants and several seeded desks; use per-session forks only if interference or deterministic walkthroughs justify the infrastructure.
- Supply an operator runbook for start, health check, seed, snapshot/restore, expiry, funding, and reset recovery. No automatic fallback to mainnet when the fork is down.

## 9. Delivery order and ownership

Keep work in small, reviewable changes that each deliver a usable slice. These are dependency-ordered milestones, not a fixed deadline or an obligation to build every optional feature.

| Milestone | Deliverable | Evidence before moving on |
| --- | --- | --- |
| A. Experience and visual foundation | Navigation, concise landing narrative, design tokens, token PNG direction, representative screens | Review desktop/mobile compositions and the first-time explanation together |
| B. Context and discovery | Parameterized integration, dynamic markets/desks, stable deep links | A second eligible desk appears without editing a hardcoded list; old/invalid desks are handled |
| C. User lifecycle | Refined lend/borrow/sell, Portfolio, Redeem | Receipts match displayed outcomes; cutoff and insufficient-repayment states are clear |
| D. Maker lifecycle | Create, configure, monitor, pause, replace, and unwind multiple desks | An interrupted setup resumes; shared exposures and residual obligations remain visible |
| E. Investor environment | Working hosted fork, funding, optional guest entry, seeded scenarios | A fresh visitor completes the demo; a reset cannot route them to mainnet |

Run the sandbox/network-identity spike early alongside A/B so it does not become a late surprise. Landing/design work can proceed independently once the integration team agrees on data and state requirements.

Suggested collaboration split:

- **Frontend lead / friend:** visual system, navigation, landing copy/layouts, responsive screens, interaction polish, token assets, and presentation of maker/user flows.
- **Sahil:** confirm financial copy and contract semantics, deployment/artifact manifest, market/desk validation, maker transaction sequences, discovery infrastructure, and sandbox feasibility/operations.
- **Shared review:** user journeys, permission explanations, fees/rates, shared position accounting, and final investor walkthrough. Agree on shared types before both editing integration files.

Prefer short-lived branches from `dev` and focused PRs. Keep visual polish, financial integration, and infrastructure changes separately reviewable. Do not merge this work into `main` during the ETHGlobal review.

## 10. Verification proportionate to the work

Do not add a broad UI test suite as a prerequisite. Keep the existing contract tests; the overhaul does not change their implementation. Use existing typecheck/build checks and a focused manual/fork checklist, adding targeted automation only where it earns its cost.

```bash
pnpm --filter @moonglade/web check
pnpm build:web
```

Before calling the demo ready, verify:

- The layout works on a narrow phone and a laptop, with keyboard-accessible dialogs and readable amounts. Assets, deep links, and refreshes work on Vercel.
- Discover a newly shipped desk, distinguish paused/docked/replaced versions, and keep the same note holding visible across those changes. Reject unsupported/spoofed candidates.
- Confirm lend, borrow, and sell amounts from receipts, including maker fee, tick rounding, actual debt, existing-credit consumption, token decimals, and allowance scope. The dashboard never substitutes a marginal rate for the user's execution rate.
- Create and reconfigure a second desk, resume after a rejected/failed step, pause safely, and complete an unwind with residuals shown. Verify shared-market debt/collateral are not double-counted.
- Exercise pre-maturity redemption, trading cutoff, successful matured redemption, insufficient repayment liquidity, zero-output dust, and sandbox reset/unavailability. Verify guest/funding/admin actions cannot reach mainnet.

## 11. Decisions to keep open

Record decisions here as the work answers them. A decision should include its reason, owner, and the evidence that made it acceptable.

| Decision | Recommended starting point | What could change it |
| --- | --- | --- |
| Main entry to the app | Market/asset and maturity first; then compare desks | User feedback favors choosing a maker directly |
| Discovery implementation | Event-based candidates with live validation; cache when needed | RPC throughput, API limitations, or missing deployment history |
| Maker setup defaults | Guided YieldSpace settings with previews; advanced raw parameters optional | Financial review finds an alternative easier to explain safely |
| Investor access | Shared isolated fork, optional guest account, one funding action | Concurrency, reset behavior, recovery needs, hosting budget |
| Rate and earnings presentation | Explicit execution-rate convention; qualified earnings estimates | Verified historical data supports stronger attribution |

Not required for this overhaul: new protocol features, new pricing models, guaranteed exits, cross-chain routing, account-abstraction contracts, an incentive token, or a production-grade analytics platform. If an experience cannot be delivered through the existing calls, describe the limitation and propose an honest UI fallback rather than changing contracts.

## Contract and code references

These files are the integration reference; read them before implementing assumptions in the UI.

- [Current web integration](apps/web/src/lib/protocol.ts), [wallet transaction flow](apps/web/src/hooks/useMoonglade.ts), and [temporary maker directory](apps/web/src/lib/makers.ts).
- [Maker setup sequence](packages/contracts/script/ConfigureMaker.s.sol) and [deployment/artifact usage](packages/contracts/script/DeployProtocol.s.sol).
- [Desk implementation](packages/contracts/src/hooks/MoongladeDeskHook.sol) and [risk/configuration interface](packages/contracts/src/hooks/interfaces/IMoongladeDeskHook.sol).
- [Note factory](packages/contracts/src/note/MoongladeNoteFactory.sol), [note redemption implementation](packages/contracts/src/note/MoongladeNote.sol), and [note API](packages/contracts/src/note/interfaces/IMoongladeNote.sol).
- [Trading cutoff and pricing instruction](packages/contracts/src/instructions/MoongladeSwap.sol), [curve parameters](packages/contracts/src/curves/interfaces/IYieldSpaceCurve.sol), [maturity demo](packages/contracts/demo/05_Maturity.s.sol), and [historical mainnet results](packages/contracts/demo/mainnet-output.md).
