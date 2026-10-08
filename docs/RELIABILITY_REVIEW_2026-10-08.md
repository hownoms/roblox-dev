# Reliability review — 8 October 2026

This review uses the current source and headless harness. No real DataStore request, multiplayer session, service configuration lookup or native profiler capture was performed by this review. Repository records identify experience `10769863381` and start place `135511260983800`; `NEXT_STEPS.md` records Limited → Playtesters access, eight passes, six products and five badges. Those records supersede older statements that no test experience exists, but they do not prove the current dashboard settings or permitted joins.

## New regressions

`tests/smoke.spec.luau` now exercises a fresh foreign session lock through retry exhaustion, verifies the rejected load leaves its data/lock intact, then releases the competing lock and loads its saved coins. It replaces that record with a new owner while the old session remains loaded and checks both autosave refusal/disconnection and final-release protection of the new owner's record. Targeted first-attempt load and save failures verify retry recovery, preservation of existing progression, successful save result and eventual release. Fault injection is limited to two disposable mock profile keys; it does not alter the real experience or production DataStore behavior.

Server mock suite: **2,186 passed, zero failed**. Studio without API access: **2,153 passed, zero failed**. These additions extend the existing overlapping-save, stalled-final-save rejoin, shutdown, terrain/tide and profiling-scope checks. They cannot establish real UpdateAsync contention, service throttling, interrupted writes or shutdown deadlines.

## Remaining real evidence

- Use the existing test experience for ordinary save/rejoin, recording source/place version and before/after coins, bag, shovel, discoveries and tutorial step. Preserve its existing saves; current records say its DataStore will also serve the future public experience.
- Foreign-lock/interrupted-write diagnostics require a scoped method against approved disposable profiles. Switching Roblox clients alone does not establish concurrent lock contention. Mock failure injection remains separate evidence.
- Four independently connected clients must verify shared holes, natural tide, player lift/recovery and ownership/reward isolation. The existing `/stress` Studio bots exercise server terrain paths, not real replication or player interaction.
- Use existing synchronous MicroProfiler labels for bot creation/steps, dig voxel reads/carves and tide fill chunks. Capture server baseline, startup, steady digging and stop/refill separately and inspect the exact expensive frame. Existing historical heartbeat spikes remain unresolved; passing smoke tests does not measure CPU/network/terrain meshing costs.

A source review also found that failure to acquire a DataStore handle enabled in-memory saves outside Studio. Live servers now reject loads when no handle exists instead of opening disposable default progression; save attempts without a live handle return false. Intentional Studio fallback is preserved. `tests/persistence-boot.spec.luau` runs in separate live/Studio mock processes and verifies rejection/no mutable save in live mode and same-process in-memory rejoin in Studio. Both scenarios pass, as do the server and Studio smoke suites above and the affected strict analysis/format check. This is injected boot-failure evidence, not a live outage test.

No speculative server optimization or persistence migration was made. Completed static asset/scenery reviews remain closed. No publication, asset upload, audience/access change, purchase or tester outreach occurred.
