# Runtime return boundary continuation — 9 October 2026

This implements requests 2–4 in Claude's latest `docs/integration/adventure-entry.md` packet without changing production boot, AdventureEntry, shared remotes, rewards, persistence, or configuration catalogs.

## Contract for Claude

`SpringVaultService.Options.ReturnFrame: ((Player) -> CFrame?)?` accepts a trusted server-side destination. Claude's `AdventureBoot.Options` should supply `ReturnFrame = function() return AdventureEntry.SURFACE_RETURN end` when his production entry module is available. Codex did not edit that shared boot file. No client-provided destination is accepted by this API.

When supplied, restore on Leave, event reset, disconnect and Destroy only moves a living current character still in the pocket: X within 48 studs, Z within 69 studs of origin.Z - 36, Y no higher than origin.Y + 20. The Y check matters for surface characters directly above the pocket. The callback is protected by pcall, and nil, invalid type or error falls back to the recorded join frame. Character identity and pocket membership are checked again after the callback, since it may yield. Surface characters and respawned characters remain where they are; cleanup still restores movement and destroys only runtime-owned loan tools. Without a callback the dedicated review's recorded join-frame behavior is preserved.

The scene now has a protected, collidable near wall spanning z +32..+34 at the open floor edge. Both the runtime exit at (0,+29) and Claude's return pad at (+10,+29) clear it by one stud. The scene remains atomic for streaming. The duplicated nested ReviewSpawn check was removed; spawn remains explicit opt-in only.

Join refusal uses the production Rookie/sold-sand/deposit wording by default; explicit `ReviewSpawn = true` retains the dedicated review-loan wording.

## Automated mock evidence

- `tests/spring-vault-return.spec.luau`: **73 checks passed**. Executes actual service and scene with API-aware mocks. Covers trusted return, immediate Leave, unready-event reset/rebuild, Destroy, nil/error/wrong-type fallback, directly-overhead surface preservation, respawn preservation, callback moving or replacing a character, loan teardown, default review return, and protected wall/return-pad clearance.
- `tests/spring-vault-runtime.spec.luau`: **38 checks passed**, including 100 assisted cleanup lifecycles and licensed runtime boundary tests.
- `tests/spring-vault.spec.luau`: **22 tests passed**.
- `tests/broadwave-dig.spec.luau`: **24 checks passed**.
- StyLua check clean on the two changed runtime files and the return spec.
- Return spec registered in `tools/adventure/check.sh` for later dedicated checks.

Bundle generated with `ROBLOX_DEFS=../roblox-dev/.tools/globalTypes.d.luau` and `python -X utf8 tests/tools/bundle.py`; tests run with `../roblox-dev/.tools/luau.exe`.

These are automated mocks. They do not validate real pocket lighting, physics collisions, network ownership, genuine streaming eviction/reload, same-account reconnection, moving physical avatars, controller/touch hardware, or populated physical-device performance. Claude's lighting rig is unchanged; its visual acceptance remains open. The boot callback is still an integration action for Claude, so this does not claim his candidate already returns directly to the surface.
