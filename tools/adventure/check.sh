#!/usr/bin/env bash
# Dedicated adventure validation; legacy production boot and trophy wiring remain unchanged.
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/bin:$PATH"
mkdir -p build/adventure
stylua --check src/server/Adventure src/shared/Adventure src/client/Adventure tools/adventure \
 tests/spring-vault.spec.luau tests/spring-vault-runtime.spec.luau tests/spring-vault-return.spec.luau tests/spring-vault-input.spec.luau tests/spring-vault-initial-stream.spec.luau tests/spring-vault-scene.spec.luau tests/spring-vault-presentation.spec.luau tests/spring-vault-outcome-owner.spec.luau tests/adventure-trophy-contract.spec.luau tests/broadwave-dig.spec.luau
rojo sourcemap adventure.project.json -o build/adventure/sourcemap.json
luau-lsp analyze --definitions="$HOME/luau-defs/globalTypes.d.luau" \
 --sourcemap=build/adventure/sourcemap.json --no-strict-dm-types \
 src/server/Adventure src/shared/Adventure src/client/Adventure tools/adventure
rojo build adventure.project.json -o build/adventure/SpringVaultAdventureReview.rbxlx
luau tests/spring-vault.spec.luau
python3 tests/tools/bundle.py
luau tests/spring-vault-runtime.spec.luau
luau tests/spring-vault-return.spec.luau
luau tests/spring-vault-input.spec.luau
luau tests/spring-vault-initial-stream.spec.luau
luau tests/spring-vault-scene.spec.luau
luau tests/spring-vault-presentation.spec.luau
luau tests/spring-vault-outcome-owner.spec.luau
luau tests/adventure-trophy-contract.spec.luau
luau tests/broadwave-dig.spec.luau
