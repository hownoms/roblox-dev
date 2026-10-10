# Production-integration review (Expansion1Review Studio place)

Branch `claude/apf-review`, based on default `5897990`. 9 October 2026. Nothing is pushed,
uploaded or published. **The shipped `AdventureFlags` are still all `false`** and no shipped
source changed: everything below is review-only and lives under `tools/expansion1/`.

> **PRODUCTION-INTEGRATION REVIEW: in-memory saves, review prerequisites; not production
> eligibility or persistence evidence.**
>
> Every session prints this banner and shows it at the bottom of the screen. A run of this review
> shows that the real production wiring works together in Studio. It does not show that real
> players are eligible (the prerequisites are seeded on request), and it does not show that saves
> persist (DataService runs on its in-memory store).

## Why this exists

Codex's dedicated review (`adventure.project.json`, `tools/adventure/Review.server.luau`) starts
`SpringVaultService` on its own, with stub admission callbacks, review loans for everyone and no
production services. It cannot show that the shipped boot works. This review runs the shipped
boot itself: production `Main`, every service, `AdventureBoot` → `AdventureBoot.Options(Flags)`
→ `SpringVaultService.Start`, `AdventureEntry`, `AdventureEligibility`, `BroadwaveLicense`,
`AdventureSettlement`, `TrophyService`, and the real client (`Main.client`, `AdventureController`,
`InputArbiter`, `BroadwaveEquip`, `AdventureOutcome`). The only thing the review changes is the
value of the three flags, and it changes them in memory before `Main` runs.

## Files

| File | What it is |
|---|---|
| `expansion1-production-review.project.json` | Rojo project. Real `src/shared`, `src/client` and `src/server` (Adventure, Services, World, and `Main` with `Disabled = true`), the review folder, production Workspace/Lighting/SoundService properties |
| `tools/expansion1/production-review/Boot.server.luau` | `ServerScriptService.ProductionReview.Boot`. Calls `ReviewBoot.Run` |
| `tools/expansion1/production-review/ReviewBoot.luau` | Gate, flag setup, boot wait, in-memory check, self-check, review helpers |
| `tools/expansion1/production-review/ReviewClient.client.luau` | `StarterPlayerScripts.ProductionReviewClient`. On-screen banner and a read-only print of `AdventureOutcome` payloads |
| `tools/expansion1/inject-production-review.py` | Read-only localhost server (127.0.0.1 only) that serves the manifest and sources for injection |
| `tools/expansion1/install-production-review.luau` | Studio command-bar installer that fetches from the injector |
| `tests/production-review.spec.luau` | Mock spec (see "Tests") |
| `tests/tools/bundle.py` | Also writes `build/test/production-review.luau` (review sources and project texts) for the spec |
| `tests/run.sh` | Registers the spec |

`default.project.json` maps none of this. The spec checks that.

## How the flags are set without touching shipped code

1. The review project maps production `Main.server.luau` as `ServerScriptService.Server.Main`
   with `"$properties": { "Disabled": true }`. It does not run on its own.
2. `ServerScriptService.ProductionReview` is a Folder that only the review project (or the
   installer) creates. Its attribute `ProductionIntegrationReview = true` is the review marker.
   `Flag_SpringVault`, `Flag_AdventureRewards` and `Flag_BroadwaveOrdinary` (all `true`) choose
   the review flags. Set one to `false` in Studio before Play to review that flag off.
3. `Boot` runs `ReviewBoot.Run`. **The gate** refuses, and starts nothing at all (not even the
   base game), unless all of these hold:
   - `RunService:IsStudio()`;
   - `game.PlaceId == 0`;
   - the marker attribute is `true`;
   - production `Main` exists, is still disabled, and has not booted (`shared.DigToTheCoreServer`);
   - DataStores are unreachable. It runs the same probe as `DataService.detectStore`
     (`GetDataStore(...):GetAsync("__probe")`). If that succeeds, saves would be durable, so it
     refuses.
4. It requires the shipped `AdventureFlags` module, sets the three fields on that table, and
   sets `Main.Enabled = true`. The engine then runs the real, unmodified `Main`. This is the same
   thing the specs do: they assign flags before `Main` runs.
5. It waits for `AdventureBoot.Runtime()`. Then it checks `DataService.IsMock()`. If that is
   false, it calls `AdventureBoot.Disable()` and kicks everyone. With PlaceId 0 this cannot
   happen, but it is checked anyway.
6. **Self-check (no resolver shim).** The review never calls `SpringVaultService.Start` or
   builds options itself. It checks the following and prints PASS/FAIL for each. If any check
   fails, it disables the adventure and marks the session "self-check failed".
   - `AdventureBoot.Runtime()` exists.
   - `AdventureBoot.Options(AdventureFlags)` builds.
   - `CanEnter`/`CanTrial` are `rawequal` to `AdventureEligibility.CanEnter`/`CanTrial`.
   - `ReturnFrame` returns `AdventureEntry.SURFACE_RETURN`.
   - `OnCompletion`/`OnStage` are `AdventureSettlement`'s (rewards on). With rewards off,
     `OnCompletion` is AdventureBoot's refusal and there is no `OnStage`.
   - `ResolveTool` is `BroadwaveLicense.ResolveTool` and `OnOrdinaryBroadwave` exists (ordinary
     on). With ordinary off, neither exists.
   - There is no `ReviewSpawn` option.
   - Codex's `AdventureReview` script and `AdventureReviewProbe` are absent.
   - Codex's `TemporaryReviewCompletionAdapter` has no submissions.
   - The hatch exists, and there is exactly one `SpringVaultAdventure` remotes folder.

   `ReturnFrame` and `OnOrdinaryBroadwave` are fresh closures on every `Options` call, so they
   are compared by behaviour or presence, not identity. The runtime does not expose its options,
   so the evidence that it received these options is that `AdventureBoot.Start` is the only
   caller, plus the adapter-submission count, which `/reviewstatus` shows. That count must stay 0
   after a completion.
7. `ReplicatedStorage` gets the attribute `ProductionIntegrationReview` = `running`, `refused: …`
   or `self-check failed`. The review client shows it.

No shipped file reads any of this. There is no new runtime seam.

## Real vs review-seeded

| Real (shipped code, unchanged) | Review-only |
|---|---|
| `Main`, every service, World, the client | The three flag values, in memory |
| Hatch "Go down" and its `CanEnter` refusal, toasts, return pad, return paths, lighting | `/reviewseed`: explicit, per player, off by default |
| `CanEnter` / `CanTrial` rules (they read the loaded save) | The seeded `Certifications.cert_rookie = { Source = "ProductionReview", ReceiptId = "review:prerequisite", Review = true }`, only if `CanEnter` is false |
| Mara join, Pip trial loan, Broadwave charge, anchors, latch, route, haul, gates | A seeded priced shovel (the cheapest) in `OwnedShovels`, only if `CanTrial` is false. Owned, not equipped |
| `AdventureSettlement` stage and final grants, receipts, trophy, outbox | The `ReviewPrerequisite` player attribute (e.g. `cert_rookie,shovel:garden_trowel`) and the `REVIEW PREREQUISITE` log line |
| `AdventureOutcome` card | The client's read-only `AdventureOutcome received (review log)` print |
| `BroadwaveLicense` / `ResolveTool` / `BroadwaveDigBridge` wiring | `/reviewhatch` (moves you beside the hatch, grants nothing), `/reviewstatus` |
| `DataService`, **in-memory store** (Studio, PlaceId 0) | Disables the Expansion1Review place's own SpawnLocation at the origin (Play-time only) |

The review never grants a `ToolLicenses.tool_broadwave` record, so no licensed tool is issued.
Codex's review loans are **adventure loans** (event and trial work only). They are never an
ordinary-dig authorization, and the journey below checks that the loan cannot dig sand.

Nothing persists. The in-memory store lives for one Play session. Stop Play, and the next session
starts with fresh, ineligible profiles.

## Load it: standalone file

```bash
rojo build expansion1-production-review.project.json -o build/Expansion1ProductionReview.rbxlx
```

Open `build/Expansion1ProductionReview.rbxlx` in Studio. It is a local file, so PlaceId is 0.
Do **not** publish it, and do not enable "Studio Access to API Services" for it. Unpublished
places have no DataStore access anyway, and the gate refuses if they do. Press Play (or
Start with 2 players for the 2-client test). `build/` is git-ignored.

## Load it: inject into the already-open Expansion1Review place

`loadstring` is blocked, so the sources are created as instances and `.Source` is set from the
command bar (plugin context).

1. In a terminal in this worktree:
   ```bash
   python -X utf8 tools/expansion1/inject-production-review.py         # serves on 127.0.0.1:34873
   python -X utf8 tools/expansion1/inject-production-review.py --check # lists roots and counts only
   ```
   It is read-only: GET only, bound to 127.0.0.1. It serves `/manifest.json`, `/source/<id>` for
   files mapped by the review project (each one must be under `src/` or
   `tools/expansion1/production-review/`), and `/installer.luau`. Everything else gets a 404,
   and other methods get a 405.
2. In Studio, in **Edit** mode (not Play), with the Expansion1Review place open: open View →
   Command Bar and paste the whole of `tools/expansion1/install-production-review.luau`. If the
   port changed, edit `PORT`. The installer:
   - turns `HttpService.HttpEnabled` on just for the fetch, then restores it. If Studio refuses
     that, allow HTTP requests in Game Settings → Security;
   - fetches every source first, so a failed fetch leaves the place untouched;
   - moves any existing `ReplicatedStorage.Shared`, `ServerScriptService.Server`,
     `ServerScriptService.ProductionReview`, `StarterPlayerScripts.Client` and
     `StarterPlayerScripts.ProductionReviewClient` into
     `ServerStorage.PreProductionReviewBackup` (renamed with a timestamp). Scripts there do not
     run;
   - creates 219 instances with production `Main` disabled, as one undo waypoint (Ctrl+Z
     reverts);
   - prints `production Main enabled = false (must be false)`.
   An agent session can run the same file through a Studio MCP `execute_luau` call (plugin
   context), with the injector running.
3. Press Play. The Expansion1Review place keeps its own Workspace settings
   (`StreamingEnabled = false`, its lighting). The installer prints which production service
   properties it did not apply. Its `ExpansionReview` script still builds the visual kit at the
   origin. That kit sits about 1000 studs below the production map, and the review disables
   that kit's SpawnLocation at Play time.
4. Do not save the place over a published place. If the place has a non-zero PlaceId, the boot
   refuses and nothing starts.

## Expected Output on Play

```
[ProductionReview] PRODUCTION-INTEGRATION REVIEW: in-memory saves, review prerequisites; not production eligibility or persistence evidence
[ProductionReview] review-only AdventureFlags (shipped source stays all false): SpringVault=true AdventureRewards=true BroadwaveOrdinary=true
[DataService] Studio has no DataStore access (...); using in-memory data.     (or "DataStores unavailable")
[ProductionReview] saves: DataService in-memory store (DataService.IsMock() == true); no DataStore is written
[ProductionReview] self-check PASS: ... (14 lines)
[ProductionReview] self-check PASS 14/14: production AdventureBoot.Options, no resolver shim
[ProductionReview] ready. Chat: /reviewseed /reviewstatus /reviewhatch. ...
[ProductionReview] <you> joined: review prerequisite OFF (real eligibility applies; /reviewseed to seed in-memory)
```

A refusal prints `[ProductionReview] REFUSED: <reason>. Nothing was started` and nothing else
happens: no map and no services.

Command bar (server context, during Play) equivalents:
`game.ServerScriptService.ProductionReview.ProductionReviewProbe:Invoke("Seed", "<PlayerName>")`.
The other commands are `"Status"`, `"Hatch"` and `"Report"`.

## Player journey checklist

Tick each one in Studio. For the 2-client test, use Test → Start with 2 players and seed only
one of them.

1. [ ] **Boot**: the banner, 14/14 self-check PASS and the in-memory line are in Output. The
   bottom-of-screen banner reads the full review text.
2. [ ] **Surface hatch**: `/reviewhatch`, or walk west past the crate yard to (-124, 1024, 76).
   The "SPRING VAULT" sign and the navy hatch with the "Go down" prompt are there.
3. [ ] **Refusal when ineligible** (before seeding): hold "Go down". You are not moved, and the
   toast reads "Spring Vault opens after your Rookie certificate, or once you have sold sand and
   dug up a deposit." `/reviewstatus` shows `CanEnter=false CanTrial=false ReviewPrerequisite=off`.
4. [ ] **Seed the review prerequisite**: `/reviewseed`. Output shows `REVIEW PREREQUISITE
   (in-memory save only; not production eligibility): <you> <- cert_rookie,shovel:<id>` and a
   toast. `/reviewstatus` shows `CanEnter=true CanTrial=true`. On a 2-client test, the other
   player is still refused.
5. [ ] **Hatch**: "Go down" lifts you into the pocket at about (-210, 973.5, 130), facing the
   vault, a few steps from **Mara**. The pocket is lit and the backdrop hides the sky.
6. [ ] **Pip loan**: talk to Pip to start the trial. The Broadwave (Adventure Loan) appears and
   the **Broadwave equip button** shows "Broadwave (loan)". Equip with the button, Z or R1.
7. [ ] **Broadwave charge**: hold and release **Q** (keyboard), **L1** (gamepad) or the touch
   button on the trial patch. The charge resolves. Q does *not* surface you while the Broadwave
   is equipped.
8. [ ] **Join** at Mara, then work through the event stages: **anchors** (excavate with the
   Broadwave), **latch** (open the vault), **route** (choose left or right), **haul** (push the
   ball; ordinary digging pauses while hauling), **gates**.
9. [ ] **Completion**: the run completes. Output on the server shows settlement activity. The
   client prints `AdventureOutcome received (review log): {...}` and the **AdventureOutcome
   card** shows the result (coins, trophy and stand, or a truthful refusal). `/reviewstatus`
   still shows `CodexReviewAdapterSubmissions=0`.
10. [ ] **Return**: use the **return pad** ("Back to the beach"), or **Leave** at the exit pad.
    Either way you land at `SURFACE_RETURN` (-112, 1030.5, 76) beside the hatch, facing the plaza,
    with the toast "Back on the beach."
11. [ ] **Ordinary digging works again**: equip your shovel and dig in the dig zone. Sand is
    collected.
12. [ ] **The loan cannot dig**: if a loan is still held, charge it on the dig strip. No sand is
    dug (the runtime, the bridge and `CanUseBroadwave` all refuse loans). After the run, the loan
    is gone from the Backpack.
13. [ ] **Stop Play** and Play again: the profile is fresh and ineligible again (in-memory store).

## Tests

`luau tests/production-review.spec.luau`, after `python3 tests/tools/bundle.py`. It is in
`tests/run.sh`. Mock coverage only: it uses the headless mock with no real engine, clients or
devices.

- **Static checks:**
  - `default.project.json` has no `tools/`, no `ProductionReview`, no `production-review`, and
    no `Disabled`;
  - the shipped `AdventureFlags` source has all three fields `= false` and none `= true`;
  - the review project maps every `src/server` child, plus `src/shared` and `src/client`;
  - production `Main` is `Disabled: true`;
  - there is no `tools/adventure`, and the marker is present.
- **Refusals:** each of these starts nothing (Main not booted, no remotes, no hatch, flags
  untouched, status `refused`):
  - not Studio;
  - PlaceId 4242;
  - no marker;
  - reachable DataStores;
  - Main enabled.
- **Studio + PlaceId 0 + marker:**
  - the real Main boots and the banner and in-memory line print;
  - 14/14 self-checks pass;
  - option identities match the production functions;
  - the probe and chat commands are installed;
  - a second boot is refused and leaves the runtime untouched.
- **Players:**
  - a fresh player is refused at the real hatch;
  - `/reviewseed` seeds a cert marked `Review = true`, `Source = ProductionReview`, and a priced
    shovel that is not equipped;
  - the `ReviewPrerequisite` label is set and the seed is logged;
  - no DataStore record is written;
  - a re-seed adds nothing and keeps the label;
  - the seeded player goes down and arrives in the pocket;
  - the unseeded player is still refused;
  - the Codex adapter has no submissions.

Result: 92 passed, 0 failed. The full `tests/run.sh` passes.

## Limitations

- **This is not persistence evidence.** Saves, settlement receipts and the outbox all use the
  in-memory paths (`DataService.IsMock()`). Durable acceptance is still `settlement-durability.md`.
- **This is not eligibility evidence.** Admission in the review comes from seeded prerequisites.
  Real players need a real cert_rookie grant, or the catch-up history.
- **No licensed Broadwave.** Nothing grants `ToolLicenses.tool_broadwave`, so the review cannot
  show licensed ordinary digging. It does show that the ordinary bridge and `ResolveTool` are
  wired, and that the loan is refused.
- **Injected sessions differ from production.** They keep the Expansion1Review place's Workspace
  and Lighting settings (no streaming), and its visual-kit script still runs. The standalone file
  uses the production settings.
- Seeding a cert_rookie means the review cannot show a player earning their *first* cert_rookie.
- The self-check proves the options `AdventureBoot.Options` builds and that Codex's adapter is
  unused. It cannot read the options object inside the runtime, which exposes none.
- These are mock tests. The injector and installer were exercised against the local server
  (manifest, sources, 404/405), but not inside Studio in this session, because another session
  owns Studio.
