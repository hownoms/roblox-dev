#!/usr/bin/env bash
# Full validation: format check, Luau strict typecheck against Roblox API, Rojo build.
# Tools expected in ~/bin (rojo, stylua, luau-lsp) and Roblox defs in ~/luau-defs.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/bin:$PATH"
status=0
echo "== stylua =="; stylua --check src || status=1
echo "== sourcemap =="; rojo sourcemap default.project.json -o sourcemap.json || status=1
echo "== luau-lsp analyze =="
luau-lsp analyze --definitions="$HOME/luau-defs/globalTypes.d.luau" --sourcemap=sourcemap.json \
  --no-strict-dm-types --ignore="**/_Index/**" src || status=1
echo "== rojo build =="; mkdir -p build && rojo build default.project.json -o build/DigTheBeach.rbxlx || status=1
[ $status -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit $status
