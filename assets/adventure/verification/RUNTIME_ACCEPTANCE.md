# Runtime acceptance continuation — 9 October 2026

Continues open draft PR #33, `codex/spring-vault-validation`, from `4f16ce0`.
Fetched origin successfully with elevated network access: default remains `520575d`.
GitHub connector confirms open, draft, unmerged and mergeable. Existing branch reused.

Read INTEGRATION.md, GAMEPLAY_POLISH.md, VALIDATION_CONTINUATION.md and their
traces/screenshots, plus Claude’s `docs/integration/README.md` and review packet.
Accepted injected Q aiming and actual two-client gate-1 recovery are prior evidence,
not repeated or promoted to hardware checks. Server-created mesh Content stays rejected.

## Ownership and proposed integration boundary

Runtime accepts external tools only through explicit `ResolveTool(player) -> Tool?`.
Claude must supply this callback from his loaded authoritative license/enablement and
issued-tool registry, returning the exact equipped tool only after
`AdventureEligibility.CanUseBroadwave(player, tool)` succeeds. Re-check on release.
Review loans cannot reach ordinary digging, even if the ordinary adapter is supplied.
`OnOrdinaryBroadwave` remains independently server validated by the existing bridge.
No boot file, configuration catalog, reward, save, trophy or camp UI is authored here.

`ReviewSpawn` defaults false. Only dedicated review opts in; production scene rebuilds
create no neutral SpawnLocation. Claude’s current disable-spawn guard remains harmless.
Client equip controls act on existing player Tools; they never issue tools or licenses.

## Automated validation

Only confirmed `Expansion1Review_AutoRecovery_0.rbxl` (PlaceId 0), currently Edit,
and its child test DataModels are authorized for Studio operations. Production
`DigTheBeach.rbxlx` is connected and untouched. No assets uploaded or publication.

Physical controller/touch, moving R6/custom player avatars, same-account network
rejoin, actual streaming/reload and crowded device performance remain acceptance gates
until separately recorded observations establish them. Mock checks are not hardware,
network rejoin or live persistence evidence. Claude owns production wiring and live
cross-server/shutdown persistence; his consolidated patch remains unapplied in this tree.


Final gameplay mocks: 22 state tests, 38 runtime checks, 191 client input/cleanup checks,
24 Broadwave real-DigService checks, 24 trophy-contract, 275 settlement and 397 trophy.
Input checks include 50 assisted mock prompt removal/reload cycles. Existing 100 runtime
completion/cleanup cycles assist progression, not traversed network runs.
Changed-file formatting, mapped strict adventure analysis, whitespace checks and both
production/review builds pass. Whole-tree formatting is not claimed: unchanged files
retain existing Windows line-ending differences.

## Claude integrated candidate (mock only)

See `INTEGRATED_CANDIDATE.md`. Reproducible runner:
`tools/adventure/check-integrated-candidate.py` (optional `focused`). It copies sources
into ignored build output, overlays Claude’s patch there, and injects a temporary
`ResolveTool` callback through `AdventureEligibility.CanUseBroadwave`. The shipped
production callback remains Claude’s responsibility. One legacy fixture spawn assertion
is updated to require zero production arena spawns; shared tracked tests are unchanged.

Full candidate baseline passed utility8, server smoke2212/2179, trophy400, settlement275,
outcome23, wired35, persistence acquisition in both mock modes, client1500, state22 and
contract24. Final focused candidate passed flags-off36, flags-on45, client arbitration20,
held-rejoin13, runtime38, input191 and Broadwave24. Actual runtime Handle begin/0.9s/release
with registered licensed equipment produced a validated ordinary scoop; loan and spoof
refusal passed. These are in-memory stores and direct Handle calls, not deployed wiring.

## Assisted Studio observations

Raw evidence: `RUNTIME_ACCEPTANCE_TRACE.json`. Dedicated local review Play only.

- Actual MCP mouse click on the equip control replicated the existing review loan into
  the unchanged player character and created RightGrip. Injected Q begin followed by
  assisted Humanoid UnequipTools sent ChargeCancel and no ChargeRelease; server
  Charging=false. This checks network equip cancellation, not physical input comfort.
- Final synchronized client layout placed the equip/stow control at `(232,425.5)` with
  98x48 size in the scrolling card at an896x635 desktop viewport. Actual mouse click
  again equipped the loan. New small-screen touch layout has not been physically tested.
- Ten server-assisted ball replacements with0.4s spacing left exactly one ball and one
  client-local smooth shell. Server MeshPart count stayed0; contact size remained7.6.
  A server-driven scene parent removal/reinsert restored one smooth shell and13 prompts.
  This is real replicated ancestry reload, not actual streaming eviction or 100 routes.
- StreamingEnabled=true in the isolated review. Teleport from arena700 to platform6000
  and wait5s left the scene loaded (183 descendants). No stream-out pass is claimed;
  streaming radii were inaccessible through this MCP execution surface. No production
  streaming settings changed. Review returned to Edit, StreamingEnabled=false.
- Existing R15 player avatar identity retained. Assisted server Humanoid MoveTo moved
  7.446 studs over2s. MCP navigation refused missing Character.PrimaryPart; the avatar
  was not replaced. Moving R6/custom player avatars remain open.
- ConnectedGamepads was empty and TouchEnabled=false. Previous failed L1 and CoreGUI
  touch injections remain failures, not hardware passes. No same-account disconnect/
  rejoin was attempted or established; Studio new-identity AddPlayers is not rejoin.

## Remaining joint gates

Claude must land/review ResolveTool alongside boot/remotes/arbitration, surface entry,
lighting, prerequisites/flags and licensed issuance. The isolated fixture is evidence of
contract compatibility, not his production acceptance. Default flags remain off and
consolidated wiring remains unapplied here. Review loans never authorize ordinary digging.

Physical controller/touch, moving R6/custom avatars, same-account network rejoin, genuine
stream-out/reload, crowded uncoached interaction, populated device CPU/GPU/memory budgets,
production EditableMesh refusal/budget and live persistence/cross-server/shutdown recovery
remain open. Runtime mesh allocation aborts at batch boundaries on teardown; client-local
geometry remains optional and primitives stay visible on API refusal. Reduced-motion
checks remain mock/past assisted evidence; no server-created EditableMesh shell returns.
Leave PR #33 draft and unmerged pending joint review. No upload or publication occurred.
