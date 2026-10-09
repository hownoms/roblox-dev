# Spring Vault adventure — integration handoff (in progress)

Branch `codex/spring-vault-adventure`, isolated worktree based on fetched default `afbb8a0`.
Production boot, legacy catalogs, saves, possessions and parallel trophy files remain untouched.

Dedicated local review: `rojo build adventure.project.json -o build/SpringVaultAdventureReview.rbxlx`.
Review boot explicitly enables prerequisite loans. It loads no DataService/EconomyService and grants no rewards.

The adventure runtime, pure progression, protected scene, client presentation and completion adapter
are being integrated and validated. This checkpoint is not a gameplay-ready or shipping claim.

Completion owner: the parallel permanent trophy/reward system. `OnCompletion(context)` receives
server-created EventInstanceId, catalog event/landmark/region IDs, validated objectives/stages,
per-user contribution and eligibility. The temporary review adapter captures at most 20 contexts
in memory and returns false with a ReviewOnly message. It never creates a persistent receipt,
coins, certifications, trophies, possessions or camp UI. No Rewarded state is asserted.

Required production wiring (proposed; not implemented): explicit feature-flagged service start,
loaded-data admission via rookie evidence, q_pip first-shovel evidence, region/protected bounds,
client controller startup with existing input arbitration, and durable stage/final settlement
through the parallel system. Preserve all legacy IDs and migration ownership. Broadwave in this
slice only clears whitelisted normalized work; ordinary Terrain carving must route through
DigService and its capacity/filled-voxel/hardness/yield validation in a separately reviewed shared
integration. Do not enable ordinary ability carving by calling Terrain directly.

No upload/publication. PR merge requires trophy boundary review together with parallel work.
Evidence and remaining gates will be filled before final delivery.
