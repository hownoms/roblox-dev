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
echo "== trophy.spec (mock store) =="
luau tests/trophy.spec.luau || status=1
echo "== adventure-settlement.spec (mock store) =="
luau tests/adventure-settlement.spec.luau || status=1
echo "== adventure-outcome.spec (client card) =="
luau tests/adventure-outcome.spec.luau || status=1
echo "== trophy-wired.spec (real Main) =="
luau tests/trophy-wired.spec.luau || status=1
echo "== production-wiring.spec (flags off / on) =="
luau tests/production-wiring.spec.luau || status=1
luau tests/production-wiring.spec.luau -a on || status=1
luau tests/production-wiring.spec.luau -a rejoin || status=1
luau tests/production-wiring.spec.luau -a client || status=1
echo "== adventure-entry.spec (flags off / on) =="
luau tests/adventure-entry.spec.luau || status=1
luau tests/adventure-entry.spec.luau -a on || status=1
echo "== broadwave-license.spec (licensed Broadwave contract) =="
luau tests/broadwave-license.spec.luau || status=1
echo "== persistence boot failure (live / Studio) =="
luau tests/persistence-boot.spec.luau || status=1
luau tests/persistence-boot.spec.luau -a studio || status=1
echo "== client.spec =="
luau tests/client.spec.luau -a "$@" || status=1
for scenario in tutorial-loop tutorial-resume-full tutorial-resume-sold tutorial-complete tutorial-veteran tutorial-scan-used tutorial-short-coins; do
  luau tests/client.spec.luau -a "$scenario" "$@" || status=1
done
[ $status -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit $status
