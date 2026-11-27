# Moonglade Frontend Standards

These rules govern all frontend work in `apps/web/` and are grounded in `PLAN.md`, `README.md`, `apps/web/README.md`, and `docs/brand/moonglade.gpl`.

## 1. Hard Boundaries
- **Never modify `packages/contracts/`.**
- **Stay on the existing stack:** `pnpm` workspace, React 19, TypeScript, Vite, Tailwind CSS v4, RainbowKit, wagmi, viem, TanStack Query, React Router. Do not migrate frameworks.
- **Branch discipline:** Work only on a feature branch cut from `dev`. Never touch `main`.
- **Strict TypeScript:** No `any`, no suppressed type errors, use `import type` for type-only imports (`verbatimModuleSyntax: true`).
- **Zero Mock Data:** Never invent fake numbers, synthetic APR calculators, or dummy positions anywhere in the app. Every displayed figure must come from confirmed onchain receipts or live RPC reads.

## 2. Brand Identity & Neo-Swiss Aesthetic
- **Standalone Wordmark:** Always render **Moonglade** as a clean lettermark (`font-weight: 600`). Never attach a moon icon to the wordmark. Moon and horizon-reflection geometry belong exclusively in hero/editorial artwork or the favicon.
- **Typography:** Use **Switzer** at its supplied weights (`400`, `500`, `600`) with `font-synthesis: none` on `html`. Never use `font-weight: 700` or `bold`, text-scaling transforms, decorative blur/glow clichés, or aggressive letter-spacing.
- **Color Authority (`docs/brand/moonglade.gpl`):**
  - Midnight `#080156`, Midnight Alt `#09015d`, Indigo Surface `#1b0ea8`, Primary Accent `#4030de`, Lavender `#8e86e0`, Light Border `#d3d0ee`, Mist `#f2f1f9`, Silver `#c9cbd9`, Moon Gold `#f2d38a`, Muted Teal `#5bb5a8`, Muted Rose `#d98ba0`.
  - Use Tailwind CSS v4 utility classes backed by semantic Light ("Daylight Mist") and Dark ("Midnight Desk") tokens in `src/styles/tokens.css`, with WCAG AA contrast and zero-FOUC initialization in `index.html`.
- **Aesthetic & Restraint:** Clean Swiss alignment, generous whitespace, `1px` hairlines, `tabular-nums` for financial figures, plain language without buzzwords, no `opacity: 0` scroll-hiding voids, and `ArrowUpRight` (`↗`) reserved strictly for external links.

## 3. Financial Copy Accuracy (`PLAN.md`)
- Retain **"Fixed-rate credit. One swap away."**
- Explain fixed-rate credit before 1inch Aqua, SwapVM, and Morpho Midnight internals.
- Never imply the protocol only supports USDC/WETH, and never imply guaranteed returns or zero risk.
- Distinguish quoted curve rates from final execution rates after maker fees and Midnight tick rounding.
- Clarify that "One swap" describes settlement after required approvals and collateral setup.
- Describe early exit as a sale at the live available quote, subject to desk liquidity and the 1-day pre-maturity trading cutoff—never guaranteed redemption at par.
- Use **"Nothing to pre-mint"** rather than implying a maker needs zero capital.
- Clearly distinguish historical Base mainnet proof transactions from current balances, live liquidity, or future performance.

## 4. Multi-Variant Isolation Rules (`v1` & `v3`)
- Keep tokens, theme provider, Switzer fonts, landing copy (`src/content/landing.ts`), shared sections, and `/docs` shared.
- Keep variant shells and landings isolated inside `src/variants/v1-hairline-rail/` and `src/variants/v3-morphing-strip/`, lazy-loaded via `src/variants/registry.ts`.

## 5. Required Verification
Every milestone or PR must pass cleanly:
```bash
pnpm --filter @moonglade/web check && pnpm build:web
```
