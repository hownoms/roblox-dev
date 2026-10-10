# Runtime safety continuation — 9 October 2026

Fetched remote default at PR #39 merge `4590614`; separate worktree/branch
`codex/spring-vault-runtime-safety`. Read the required integration and continuation
handoffs first. Independent agents audited server runtime, client input and actual
merged production provisioning. No other chat was messaged.

## Substantive input fix

A dead avatar can retain its equipped Tool until character removal. Previously the
client considered that tool sufficient to own Q/L1/touch and kept a held charge
alive. SpringVaultClient now requires a living Humanoid for charge input and cancels
held charges on the next rendered frame or input edge. Death immediately before
release sends Cancel instead of Release. Server validation remains authoritative;
loans still cannot authorize ordinary digging. No new lifecycle subscriptions,
boot adapters, resolver or scene substitutes were added.

`runtime-safety/input-death-before.log` records the actual source-module regression
failing against the baseline. `input-death-after.log` and `regressions.log` record
the corrected result. These are API-aware headless mocks, not physical input.
Server audit found no additional normal-flow defect justifying a change. Existing
equipment restoration, avatars, fixed contact geometry, reduced motion and local
smooth geometry/primitive fallback remain unchanged.

## Actual candidate and release gates

Studio MCP returned `{"studios":[]}` before changes. No loaded DataModel, Play,
ordinary UI input, screenshots, injected input or assisted navigation was available
or performed. No production Studio, publication, upload or live save test occurred.
Prior accepted trial aiming/two-client recovery evidence is reused; PR #36 remains
injected review input with assisted navigation, not production/uncoached acceptance.

No Claude candidate delivery exists in fetched default:

- DataService acquires the player store at line 304 before Studio probe/fallback
  at 315–321. MonetizationService acquires purchase history at 295 before checking
  IsMock at 297. Explicit fail-closed local candidate storage before any real store
  acquisition is absent. Candidate server flags/production lifecycle and ordinary
  eligibility must be supplied as described in launch-blockers/CLAUDE_CANDIDATE_HANDOFF.md.
- AdventureController still waits in withScene (84–100); runtime and shared equip
  start inside begin (47–61). PR #39 accepts a nil scene but the production controller
  has not adopted it. This continuation does not repeat that API work.
- No legitimate gameplay writer grants ToolLicenses.tool_broadwave or cert_rookie.
  The honest current entry path is recorded sale plus excavated deposit; Pip trial
  requires a purchased shovel. Permanent licensed pre-replication and stream-out
  acceptance remains blocked by the grant and controller dependencies.

AdventureBoot already supplies ReturnFrame and ResolveTool; these are not blockers.
Entrance/Mara/Begin, Pip exit, full adventure, shared equip and exact PR #37
restoration, Leave/automatic return and truthful per-player memory-simulation reward
results still need safe actual production candidate UI acceptance. No production
acceptance gate closed here. Hardware/uncoached play, populated streaming/performance
and cross-server durability remain open separately.

## Validation

Targeted actual-source mocks pass: state22/runtime47/return111/input293/initial-stream16/
scene81/presentation53/Broadwave24/trophy-contract24. Actual merged integration
without fixture patch or injected resolver passes wiring off37/on42/rejoin13/client61,
entry off16/on69, license61, settlement275 and outcome23. Logs are in runtime-safety.
These use isolated in-memory mocks and cannot establish production input or durability.
Changed-file formatting, whitespace, mapped strict adventure analysis and local
production/review builds pass. Keep the PR draft and unmerged.
