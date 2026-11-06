---
name: solidity-style
description: Apply Moonglade's Solidity coding and API conventions when creating, modifying, or reviewing contracts, libraries, interfaces, tests, and scripts under src/, test/, and script/. Covers naming, imports, NatSpec, storage visibility, getters, and contract layout. Do not use for non-Solidity work.
---

# Solidity Style

Apply these rules to Moonglade's Solidity under `src/`, `test/`, and `script/`. Inspect neighboring files and `foundry.toml` before editing. Preserve established local structure unless this skill states a mandatory rule. Do not restyle third-party code under `dependencies/`.

## Tooling and files

- Match the pragma used by neighboring files and respect dependency compiler constraints. Midnight and SwapVM currently require separate Solidity 0.8.34 and 0.8.30 compiler graphs; do not normalize their pragmas to one version. Preserve compatibility pragmas in interfaces and mocks unless the task requires a change.
- Let `forge fmt` enforce four-space indentation, import sorting, and the 120-character line limit.
- Name contracts, libraries, and interfaces `PascalCase.sol`; name tests `*.t.sol` and scripts `*.s.sol`.
- Declare one interface per file.
- Use workspace-root import paths such as `src/...`, `test/...`, and dependency remappings. Do not add `./` or `../` imports.

## Imports

Group imports in this order, separated by blank lines:

1. External dependency interfaces.
2. External dependency contracts and libraries.
3. Local interfaces.
4. Local contracts and libraries, including test helpers.

Use existing libraries under `src/libraries/` when they already implement the needed behavior. Extract new shared logic only when it has more than one real consumer or is independently security-critical; do not create speculative abstractions.

## Naming

- Use `PascalCase` for contracts, libraries, structs, and enums.
- Prefix interfaces with `I`.
- Use `camelCase` for functions and local variables.
- Prefix function, event, and error parameters with `_`.
- Return explicit locals; do not use named return parameters.
- Use `SCREAMING_SNAKE_CASE` for constants.
- Use `camelCase` for immutables and other state variables, without `i_` or `s_` prefixes.
- Name custom errors `Module__Reason`, with parameters when they materially improve diagnosis.

## Interfaces and integration surfaces

- Treat interfaces as stable integration contracts for UIs, indexers, and external protocols.
- Declare structs, enums, events, errors, and explicitly implemented public or external function signatures in the corresponding interface.
- Public state variables may provide integration getters; do not require separate getter implementations or `get...` wrappers. Declare generated getter signatures in interfaces when interface consumers need them.
- Document interface enums, structs, struct fields, events, and errors with NatSpec.
- Do not add NatSpec to interface function declarations; document behavior on the implementation.
- Group interface functions by configuration, user actions, and views where applicable.

## NatSpec

- Add `///` NatSpec to public or external contracts, public or external implementation functions, events, constructors, state variables, constants, immutables, and internal functions.
- Give each core contract `@title`, `@author`, `@notice`, and `@dev` tags. End `@title` and `@author` values with periods.
- For public or external functions, cover purpose, parameters, state changes or external calls, trust assumptions, and material edge cases such as rounding or fees.
- Add `@return` for every returned value.
- Avoid comments that merely restate code. Do not leave context-free TODOs.
- Do not add NatSpec to tests; use descriptive test names and comments that explain non-obvious setup or assertions.

## Storage and getters

- Choose `public`, `internal`, or `private` state visibility according to intended access; there is no mandatory default.
- Use public state variables and their generated getters when appropriate. Add explicit getters only when custom behavior or a different integration surface is needed.
- Order contract members as: constants, immutables, state, constructor or initializer, admin/configuration functions, user functions, internal functions, external views, public views.
- Separate major function groups with the repository's existing section comments.

## Validation and external calls

- Prefer custom errors.
- Call every library explicitly by name, passing the receiver as the first argument: use `SafeERC20.safeTransfer(_token, _receiver, _amount)` or `SafeCast.toUint128(_value)` rather than extension-method syntax. Do not add `using ... for ...` directives, including function or operator aliases. This also applies to globally attached helpers; call packages exposing free functions directly through an imported namespace.
- Avoid modifiers; use focused internal validation functions unless inheritance or an external standard makes a modifier necessary.
- Update internal state before untrusted external calls. If this ordering cannot be followed, document the reason, add explicit reentrancy mitigation, and test the reentrant path.
- Treat token callbacks, ERC777 hooks, adapters, vaults, oracles, and arbitrary batch calls as untrusted boundaries.
- Use assembly only when necessary. Explain why it is needed, constrain inputs and outputs, and add focused tests.

## Scripts

- Use a `Config` struct and `_loadConfig()` reading variables listed in `.env.example`.
- Import `Script` from `forge-std/Script.sol` using the Soldeer remapping in `remappings.txt`.
- Use `vm.startBroadcast()` and `vm.stopBroadcast()` for stateful execution.
- Keep deployment scripts separate from provider or admin configuration scripts.
- Keep scripts deterministic and secrets out of source.

## Validate

After Solidity changes, run from the repository root:

```bash
forge fmt
forge build
forge test
```

Explicit user instructions about verification take precedence. While tests are paused for protocol review, run `forge fmt --check` and `forge build --skip test` instead; do not run tests, and report that they remain paused.

Report each command and its outcome, including skipped checks. Do not commit or push with known formatting, build, or test failures.
