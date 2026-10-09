# Production journey continuation — 9 October 2026

Started from fetched default `1a29c30` (merged PR #36), isolated `codex/spring-vault-production-journey` worktree. Read INTEGRATION, DISCOVERY_CONTINUATION and JOURNEY_CONTINUATION first. Independent agents implemented runtime equipment recovery and shared input presentation.

## Player-visible fixes

The runtime fallback equip button now defers to the actual production `Dig_Broadwave` HUD. Its Activated handler also refuses to compete with that HUD. Production keeps its existing tool selection, Z/R1 toggle and shovel-restoring stow; dedicated review retains the fallback.

Returning an adventure loan now re-equips the exact tool held before the loan was issued, when it remains in the player's Backpack, the original living character remains current, and no other tool is equipped. It neither recreates possessions nor overrides a later equipped tool. Leave, optional trial exit, automatic completion return and runtime destruction share this cleanup. Dead/replaced characters and removed possessions are not restored.

## Loaded candidate and input boundary

Read-only Studio MCP inspection confirmed `Expansion1Review.rbxlx`, PlaceId 0, Studio `5c9a8359-4e4a-40d9-8e99-216f19d6fa27`, Edit. `AdventureReview` explicitly enables ReviewSpawn and unconditional CanEnter/CanTrial, with no production services/rewards. Server children are ExpansionReview, Adventure and AdventureReview; client uses only AdventureReview. See `production-journey/loaded-candidate.json`.

No Studio mutation or input acceptance was performed in this continuation. This is not the actual production candidate: Main, AdventureBoot, AdventureEntry, shared production HUD and reward services are absent. Replacing review boot would require bypassing the shipped-off production flags and prerequisites; actual DataService probes DataStore access before fallback, so running it here would not guarantee no live save access. No temporary wiring, resolver, bypass or mock candidate was installed. Studio remains Edit; production Studio, uploads, publication and live saves were untouched.

Production entrance → Mara → Join/Begin, Pip exit → main adventure, unassisted anchors/latch/route/attachment/gates/ending, Leave/automatic return and truthful per-player reward UI therefore remain unverified in Studio. The exact next prerequisite is a safely provisioned actual production integration candidate in the authorized review DataModel with legitimate eligibility and live-save access excluded. This continuation does not change Claude-owned boot, arbitration, entry, catalogs, rewards, persistence, trophies or camp.

PR #36's injected mouse/E journey with assisted navigation remains accepted review evidence, not production/uncoached acceptance. Prior accepted trial aiming and two-client recovery are reused: aiming, movement authority, contact geometry and checkpoint recovery were unchanged. No direct remote request was used as input acceptance.

## Validation and evidence

Before/after source and mock evidence is in `production-journey/`; runtime regression evidence demonstrates the old failure and corrected behavior. Targeted regression and actual merged integration checks use API-aware headless mocks and in-memory stores. They establish code behavior, not physical device input, deployed production acceptance or live durability.

Actual merged wiring off/on/rejoin/client, entry off/on, license, settlement and outcome checks pass without applying the old integration fixture script. ResolveTool and ReturnFrame are present in actual AdventureBoot and are not blockers. Changed-file formatting, whitespace, mapped strict adventure analysis, dedicated review build and actual production build pass. Loans remain unable to authorize ordinary digging; validation, avatars, fixed ball geometry, cancellation, reduced motion and client-local mesh fallback are preserved.
