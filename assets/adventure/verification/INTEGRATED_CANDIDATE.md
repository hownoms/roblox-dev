# Integrated candidate mock evidence — 9 October 2026

Ignored fixture only: copied src/tests/project JSON, applied docs/integration/adventure-integration.patch inside build/adventure/integrated-candidate, then injected temporary AdventureBoot.Options.ResolveTool. The callback scans equipped character tools through AdventureEligibility.CanUseBroadwave, which verifies BroadwaveLicense's issued registry, loaded permanent license, feature enablement, ToolId, non-loan status and equipped ownership. No tracked shared boot/remotes/arbitration/catalog changes.

Initial full suite: util8, smoke2212 live/2179 Studio, trophy400, settlement275, outcome23, trophy-wired35, production-wiring off36/client20/rejoin13, persistence boot live+Studio, client1500, state22, runtime36, input191, Broadwave24, trophy-contract24 passed. Flags-on initially43 passed/2 failed: legacy test demanded at least one disabled review spawn although new runtime correctly creates none; actual runtime accepted loan charging globally when an ordinary adapter existed. No ordinary sand was granted by that loan. Runtime owner fixed charge gating.

Final focused rerun after fix: production-wiring off36/on45/client20/rejoin13; runtime38; input191; Broadwave24 passed, zero failures. Additional flags-on rerun explicitly verified zero SpawnLocations and zero enabled SpawnLocations,45 passed. The fixture-only legacy assertion was updated accordingly.

Added fixture assertions prove actual SpringVaultService.Handle ChargeBegin,0.9-second mock hold and ChargeRelease with registered equipped licensed tool scoops through the real DigBroadwave adapter. Resolver refuses review loan despite loaded license and spoofed attribute tool. Runtime refuses ordinary loan charging away from event/trial and loan release never grants sand.

Limits: API-aware headless mock with in-memory DataStores; direct Handle calls, not network clients or physical input. This is not actual production boot deployment, real streaming/reload, same-account network rejoin, cross-server durability, shutdown recovery, hardware QA or device performance. Claude must explicitly implement/review the authoritative ResolveTool boot callback; the fixture adapter does not land it. Shared integration patch remains unapplied in tracked source and flags stay default off.

Logs: integrated-candidate-initial.log; integrated-candidate.log; integrated-zero-spawns.log. Initial/final results JSON include copied Luau source hashes; final zero-spawn assertion tightening is retained in runner and additional log after the final manifest was written.
