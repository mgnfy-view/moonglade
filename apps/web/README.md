# Moonglade web

React + TypeScript + Vite with RainbowKit, wagmi, and viem. This migration preserves the existing Swiss-style landing,
maker list, and lend / borrow / sell flows. The current directory lists one Base USDC desk with WETH collateral.

From the repository root:

```bash
pnpm install --frozen-lockfile
pnpm dev
pnpm build:web
```

Open `http://localhost:5173`. `pnpm preview` serves the production build. Frontend development needs no Foundry setup.

Optional public settings are listed in `.env.example`: `VITE_BASE_RPC_URL` and `VITE_WALLETCONNECT_PROJECT_ID`.
Browser wallets work without a WalletConnect project ID. Never copy the contracts package's `.env` into this app.

Integration code is in `src/hooks/useMoonglade.ts` and `src/lib/`. Contract addresses are in `src/lib/contracts.ts`;
the temporary maker directory is in `src/lib/makers.ts`. Solidity lives in `../../packages/contracts`.

Dependency and font notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
