# Moonglade contracts

Foundry/Soldeer workspace. Run direct Forge commands from this directory; Solidity imports remain relative to this
package's root (`src/...`, `test/...`, `demo/...`). Follow the repository's Solidity style skill.

From the repository root:

```bash
pnpm contracts:deps
pnpm build:contracts
pnpm --filter @moonglade/contracts check
pnpm test
pnpm demo borrow
```

Foundry v1.9.0, Solidity 0.8.30/0.8.34, Osaka, and the committed `soldeer.lock` preserve the existing toolchain.
The original sources, deployment scripts, test suite, demos, and deployed addresses are unchanged.

Copy this package's `.env.example` to `.env` for deployment configuration. `out/`, `cache/`, `broadcast/`,
`dependencies/`, and `.env` are local and ignored. Existing local state was moved here with the migration.
Deployment instructions and live receipts are linked from the [root README](../../README.md).
