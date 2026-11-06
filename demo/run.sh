#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

rpc_url="${BASE_RPC_URL:-https://mainnet.base.org}"
fork_block="${DEMO_FORK_BLOCK:-52000000}"
export DEMO_FORK_BLOCK="$fork_block"

case "${1:-all}" in
  01|maker) targets=("01_MakerSetup.s.sol:MakerSetupDemo") ;;
  02|lend) targets=("02_Lend.s.sol:LendDemo") ;;
  03|sell) targets=("03_SellNotes.s.sol:SellNotesDemo") ;;
  04|borrow) targets=("04_Borrow.s.sol:BorrowDemo") ;;
  05|maturity) targets=("05_Maturity.s.sol:MaturityDemo") ;;
  06|shared) targets=("06_SharedLiquidity.s.sol:SharedLiquidityDemo") ;;
  all) targets=(
    "01_MakerSetup.s.sol:MakerSetupDemo"
    "02_Lend.s.sol:LendDemo"
    "03_SellNotes.s.sol:SellNotesDemo"
    "04_Borrow.s.sol:BorrowDemo"
    "05_Maturity.s.sol:MaturityDemo"
    "06_SharedLiquidity.s.sol:SharedLiquidityDemo"
  ) ;;
  *) printf '%s\n' "Usage: bash demo/run.sh [all|maker|lend|sell|borrow|maturity|shared]" >&2; exit 2 ;;
esac

# Build both exact compiler graphs before scripts load deployment artifacts.
forge build --offline --no-lint --quiet

run_script() {
  forge script "demo/$1" --offline --fork-url "$rpc_url" --fork-block-number "$fork_block" --color never -vv "${@:2}"
}

run_script "${targets[0]}" --sig "showConfig()"
for target in "${targets[@]}"; do
  run_script "$target"
done
