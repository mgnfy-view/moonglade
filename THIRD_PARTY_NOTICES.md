# Third-party notices

The root [MIT License](LICENSE.txt) covers Moonglade's original contributions.
It does not replace third-party licenses or grant MIT-only rights to combined
source or compiled artifacts incorporating third-party code. Dependency versions
and full Git revisions are pinned in `foundry.toml` and `soldeer.lock`.

## SwapVM

Powered by SwapVM — © Degensoft Ltd 2025

SwapVM 1.0.2, revision `32c687c2b73101fc26549e48fa1ff8a4d73afbac`, is licensed
under [LicenseRef-Degensoft-SwapVM-1.1](LICENSES/LicenseRef-Degensoft-SwapVM-1.1.txt).
This is a source-available license with copyleft and commercial-use conditions.
It permits noncommercial hackathon use subject to its terms.

The upstream source is installed unmodified by Soldeer. Moonglade's
`src/instructions/MoongladeSwap.sol`,
`src/opcodes/MoongladeOpcodes.sol`, `src/routers/MoongladeRouter.sol`,
`src/routers/interfaces/IMoongladeRouter.sol`, `src/hooks/MoongladeDeskHook.sol`,
and `src/hooks/interfaces/IMoongladeDeskHook.sol` carry
`MIT AND LicenseRef-Degensoft-SwapVM-1.1` identifiers. Preserve the applicable
upstream license and notice requirements when distributing these components.

## Aqua

Powered by Aqua — © Degensoft Ltd 2025

Aqua 0.1.0, revision `b51f3b6e3c02fa5208e1429f0f14706b025d9dd6`, is licensed
under [LicenseRef-Degensoft-Aqua-Source-1.1](LICENSES/LicenseRef-Degensoft-Aqua-Source-1.1.txt).
This is a source-available license with copyleft and commercial-use conditions.
Aqua is installed unmodified by Soldeer; its source and artifacts retain that
license.

Moonglade uses Aqua interfaces and its deployed registry for shared-liquidity
strategies. The router and desk-hook integrations listed above use SwapVM's
Aqua settlement path; their original contributions do not replace the licenses
of the upstream code they incorporate.

## Morpho Midnight

Midnight revision `7565b9adb3335c1284a3c2525523cda7c07b9fa7` is installed under
the Soldeer snapshot label `0.0.0`. Its interfaces and libraries use MIT; its core
`src/Midnight.sol` uses Business Source License 1.1, copyright 2026 Morpho
Association. Consult the pinned upstream
[LICENSE](https://github.com/morpho-org/midnight/blob/7565b9adb3335c1284a3c2525523cda7c07b9fa7/LICENSE)
and [LICENSE-MIT](https://github.com/morpho-org/midnight/blob/7565b9adb3335c1284a3c2525523cda7c07b9fa7/LICENSE-MIT)
for the full terms, including the additional-use-grant and change-license
parameters. The root MIT license does not relicense Midnight's core.

## Fork demos

The scripts in `demo/` use forge-std for local deployment, fork setup, and
console output. They call official Aqua and Midnight deployments on a Base
fork without replacing either protocol's bytecode. Moonglade contracts and
the demo oracle deploy locally; market configuration and opening balances
are fork-only fixtures.

Moonglade's demo sources carry MIT identifiers for their original code.
Imported dependency source and compiled artifacts remain subject to the
applicable upstream licenses described here.

## Other dependencies

| Dependency | Version | License |
| --- | --- | --- |
| OpenZeppelin Contracts | 5.4.0 | [MIT](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.4.0/LICENSE) (also identified in installed source headers) |
| PRBMath | 4.1.0 | `dependencies/prb-math-4.1.0/LICENSE.md` (MIT) |
| 1inch Solidity Utils | 6.9.7 | `dependencies/solidity-utils-6.9.7/LICENSE.md` (MIT) |
| forge-std | 1.16.2 | `dependencies/forge-std-1.16.2/LICENSE-MIT` or `LICENSE-APACHE` (MIT OR Apache-2.0) |

Preserve the upstream copyright and license notices when redistributing their
code or artifacts. Dependency directories and their notices are restored with
`forge soldeer install`.
