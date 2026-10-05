#!/usr/bin/env bash
# Runs the pure unit tests and the headless server + client smoke tests (tests/mock/Roblox.luau).
#   tests/run.sh            all tests
#   tests/run.sh verbose    also print server print()/warn() output
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/bin:$PATH"
status=0
echo "== util.spec =="; luau tests/util.spec.luau || status=1
echo "== smoke.spec =="
python3 tests/tools/bundle.py || exit 1
luau tests/smoke.spec.luau -a "$@" || status=1
echo "== smoke.spec (Studio, no DataStore access) =="
luau tests/smoke.spec.luau -a studio "$@" || status=1
echo "== client.spec =="
luau tests/client.spec.luau -a "$@" || status=1
[ $status -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit $status
