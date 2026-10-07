#!/usr/bin/env bash
# Launch preflight: lists every Creator Hub id / owned asset still to fill in, and anything that
# must not ship (e.g. the Studio grant-all-passes switch). See docs/LAUNCH.md.
#   tools/preflight.sh          report; fails only on blocking issues
#   tools/preflight.sh strict   also fails while any placeholder remains (use right before publishing)
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/bin:$PATH"
python3 tests/tools/bundle.py >/dev/null || exit 1
luau tests/preflight.luau -a "$@"
