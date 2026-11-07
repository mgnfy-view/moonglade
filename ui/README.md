# Moonglade UI

Client-only React + Vite app with RainbowKit wallets. Landing → makers → lend / borrow / sell on Base.
The directory lists one deployed USDC desk with WETH collateral.

```bash
cd ui
npm ci
npm run dev
```

Open `http://localhost:5173`. Build with `npm run build`; preview with `npm run preview`.

**Vercel:** import the repo, set root directory to `ui`, framework to **Vite**, build command to `npm run build`,
and output directory to `dist`. SPA routing is included in `vercel.json`.

No environment configuration is required. Optional public settings in `.env.example`:

- `VITE_BASE_RPC_URL`: browser-accessible Base RPC.
- `VITE_WALLETCONNECT_PROJECT_ID`: enables WalletConnect; browser wallets work without it.

Contract addresses: `src/lib/contracts.ts`. Maker listing: `src/lib/makers.ts`.
Dependency and font notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
