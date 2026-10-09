# Spring Vault validation continuation — 9 October 2026

Separate worktree `spring-vault-validation`, branch `codex/spring-vault-validation`,
based on fetched default `777afa27f11b421213b781c51876ef77bbe7ba05` (merged PR #32).
Started there; final fetch incorporated Claude's advanced default `520575d` without
conflicts. Read PR #32's
integration handoff, gameplay report, trace and screenshots before choosing new checks.
Only Expansion1Review and its child local test clients/server were operated. When the
review disconnected and DigTheBeach was the only connected place, no production MCP
operations were performed; a new locally built Expansion1Review was opened instead.
No uploads, publication, production boot/catalog changes or live DataStore writes.

## Changes

- Broadwave charge feedback explicitly describes avatar-facing aim and readiness.
  A local nonquery/noncolliding footprint previews the validated horizontal corridor.
  Focus loss, text entry and ten-second timeout cancel charging. Q/L1/touch ownership
  prevents another input releasing a held charge. Server acceptance is unchanged.
- Scene ancestry removal clears charges, effects, prompts and local ball presentation;
  unavailable scenes cannot begin a new charge. Atomic scene streaming prevents partial
  arena replication. Production streaming distances and boot settings are unchanged.
- Beach-ball presentation now creates one smooth spherical sector surface **on each
  client**, with radial normals, colored panels and cream gutters. 9,024 triangles;
  batched creation yields. No asset IDs, uploads or place-permission changes. The
  original PR #32 primitives remain the server presentation and refusal fallback.
  Clients hide those locally only after successful local mesh creation. The original
  7.6-stud noncolliding query/contact sphere stays authoritative. Local shell follows
  contact motion and disposes its EditableMesh and connections on teardown.

Server-created local EditableMesh Content rendered a checkerboard placeholder on
actual clients despite exposing an Object content value. That rejected approach is
recorded in `studio-ball-server-content-refused.png`; it is not the delivered path.
`studio-ball-smooth-local-client.png` verifies the final locally created client shell.
`studio-ball-smooth-local-edit.png` is an earlier isolated Edit geometry observation.
Fallback seams remain faceted wherever local EditableMesh is unavailable; runtime
reports `PrimitiveFallback` explicitly. Memory/device permission gates remain open.

## Automated checks

API-aware headless mock, not physical devices, actual streaming or live DataStores:

- 22 progression/movement tests; 25 actual-service runtime checks; 33 actual-client
  input/cleanup checks. Runtime fixture reaches gate 1 through validated mock movement,
  verifies repeated checkpoint reset and replaces a Player object with the **same
  UserId**, retaining earned contribution and cooldown without automatic attachment.
  100 assisted completion/cleanup cycles remove loans/scenes/remotes and restore speed.
  These cycles assist objective progression; they are not 100 traversed network runs.
- Input fixture executes actual Q/L1/touch callbacks, mixed-input and distinct-finger
  ownership, focus/timeouts, ancestry removal, replacement scene prompts and teardown.
  Unsupported mesh API retains visible fallback; no fake EditableMesh mock success.
- 23 unchanged Broadwave/DigService integration checks; 24 trophy-contract checks;
  153 settlement checks and 312 trophy checks. These reward checks use mocked stores.
- Existing server smoke: 2,212 live-mode / 2,179 Studio-mode checks. Existing client
  smoke: 1,464 checks. Focused formatting, strict mapped adventure analysis, whitespace
  validation, dedicated review build and production build pass.

## Assisted Studio observations

Raw records: `VALIDATION_CONTINUATION_TRACE.json`.

- Equipped review loan, assisted horizontal avatar positioning six studs in front
  of Pip's patch, and injected Q hold produced actual client ChargeBegin/Release
  RemoteEvent delivery and **Trial.Wave=true**. Repeated on final client code with
  approximately 0.985-second server-observed hold. This closes accepted injected
  keyboard aiming; it does not establish physical keyboard comfort or uncoached aim.
- Actual StudioTestService two-client local server, NetworkClients Player1 (-1) and
  Player2 (-2). Client scripts sent actual Intent requests; server teleports assisted
  objective positioning and Humanoid MoveTo drove hauling. Late helper excavated,
  both attached, and gate 1 validated. Eight client reset requests over four seconds
  restored the exact gate-1 position `(692,20,-36)`, retained gate 1 and both points
  (19.8573317597 / 25.1426682403), detached both, restored speeds 16. EndTest ended
  the isolated local test. Prior PR #32 already supplied the full three-gate run.
- Final actual client shell rendered with smooth cream gutters, no checkerboard;
  server remained PrimitiveFallback and client LocalSmoothSectors. Assisted server
  ball relocation left local shell/contact separation 0; contact stayed 7.6 studs.
  Existing player's R15 avatar identity was retained; it was not replaced for testing.
- Galaxy A06 landscape emulator: 705×338, LandscapeSensor review orientation.
  Centered scrolling review card stayed between movement/jump controls. This is
  layout emulation, not physical touch operation.
  Found and corrected generated Broadwave/Jump overlap: final Broadwave64×64 at
  `(616.5,103)`, Jump70×70 at `(610,190)`, leaving a23-pixel vertical gap.
  The card hides while charging and restores on release; `studio-phone-charge-aim.png`
  shows the final unobstructed readiness hint and aiming footprint. Injected Q
  provided that screenshot. MCP mouse injection on the generated touch control was
  refused as hitting CoreGUI and delivered no charge request; physical touch stays open.
  Studio returned to Edit and reset to the default viewport after emulator checks.

## Remaining joint acceptance gates

Physical controller and phone operation are still unverified. Prior L1 injection
produced no network requests; callback mock coverage does not convert that into a
hardware pass. Moving R6 and custom player avatars, same-account **network** rejoin,
actual streamed-out/reloaded gameplay, crowded uncoached interaction and populated
device performance remain open. Same-UserId replacement in the mock is distinguished
from Studio's previous AddPlayers new identity (-3).

Production must still inject licensed BroadwaveDigBridge/DigService.DigBroadwave,
provide authoritative permanent equip/prerequisites/flags and arbitrate Q/L1/E against
ordinary digging/HUD. Claude owns boot integration, durable rewards/settlement,
certifications, trophy storage and camp display. Mock settlement passing is not live
cross-server durability, shutdown recovery or truthful wired per-player outcomes.
Keep this PR unmerged for joint review with Claude's integration. Nothing published.

## Latest-default combination

Default advanced during final review to `520575d`, incorporating Claude's consolidated
integration packet and outcome/camp/boot modules. This worktree fast-forwarded to that
default with gameplay edits retained; no Claude-owned files were authored here.
Read `docs/integration/README.md` and `codex-polish-review.md`. The consolidated
`adventure-integration.patch` remains **unapplied**, flags default off. Its module
preparation is not proof that boot, remotes and arbitration are wired in production.

Combined checks: production-wiring flags-off36, outcome UI22 (explicitly reports remote
wiring unexercised), settlement275, trophy397, trophy-contract24, runtime25, input33,
and client smoke1500.
Full source strict analysis has only the two existing deprecated friendship/group API
warnings. Production/review builds pass. Earlier baseline counts above are the premerge
run; see this section for updated reward/UI counts. Wired flags-on tests are not claimed.

Claude's production review still blocks enablement on the neutral review SpawnLocation,
runtime accepting only its own loan rather than the licensed tool, hidden Backpack with
no equip control, and surface entry/lighting for the protected pocket. Resolve these
through the joint runtime/boot boundary; do not enable BroadwaveOrdinary to bypass the
loan/licensed-tool distinction. Live DataStore/cross-server/shutdown recovery stays open.
