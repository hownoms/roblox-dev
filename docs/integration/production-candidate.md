# Spring Vault production candidate (Expansion1Review, local-only storage)

Branch `claude/spring-vault-production-candidate`, 10 October 2026, on default `d96ac75`.
**Played and tested commit: `470465f`.** Not merged, published or uploaded. No live save test
was run. Every `AdventureFlags` flag still ships `false`. The candidate turns them on only inside
the authorized Studio place, through its own server config.

This answers `assets/adventure/verification/launch-blockers/CLAUDE_CANDIDATE_HANDOFF.md` and the
runtime-startup and runtime-safety continuations. It replaces the seeded production review
(`production-review.md`) for acceptance purposes. That review and the earlier player-flow run
(`player-flow.md`, on `656f3f9`, before Codex's PRs #36–#40) used seeded prerequisites and are not
production acceptance. This run uses normal new-player data and the final merged tree.

## 1. What changed

| Piece | Where | What |
|---|---|---|
| Fail-closed local-only storage | `src/server/Services/CandidateProfile.luau`, `StorageGate.luau`, `Main.server.luau`, `DataService`, `DurableOutbox`, `MonetizationService`, `LeaderboardService`, `AdventureFlags` | See section 2. |
| Runtime before arena replication | `src/client/Controllers/AdventureController.luau` | Adopts PR #39's `SpringVaultClient.Start(remotes, nil)`. The runtime starts from the remotes alone when the player is in the arena or has a Broadwave in hand. It never creates or fakes a scene. Arena-only behaviour still needs the real scene. |
| Permanent Broadwave license from q_pip | `src/server/Services/PipQuest.luau`, `AdventureBoot` | Completing Pip's trial grants `ToolLicenses.tool_broadwave` once, from server state only. See `pip-quest-license.md`. |
| Rides kept out of the pocket | `RideService.SetSpawnGuard`, `AdventureEntry` | Measured: the old 40-stud horizontal check let a ride spawn from the pocket and carry the player out. Now it is refused ("Rides stay on the beach."), and any ride is despawned on entry. |
| Candidate provisioning | `expansion1-production-candidate.project.json`, `tools/expansion1/production-candidate/`, `tools/expansion1/{inject,install,uninstall}-production-candidate.*` | Section 3. |

The branches merged in: `claude/svc-storage` (`9f56f84`), `claude/svc-client` (`c89ba63`) and
`claude/svc-pipquest` (`6187412`). The only conflict was `tests/run.sh`, which kept both sides.

## 2. Local-only storage: chosen before anything starts, fails closed

`CandidateProfile` is resolved by Main **right after the duplicate guard, before
`Remotes.CreateAll`, `World.Build` or any service module is required**.

- **No `ServerScriptService.ProductionCandidate` folder:** `Production`. The game behaves exactly
  as before, including the existing Studio probe and fallback.
- **Folder present:** `LocalOnly` only when every check below holds. Otherwise `Refused`, and Main
  starts nothing: no remotes, no world, no services, no DataStore.
  - Studio and server;
  - `PlaceId == 0` and `GameId == 0`;
  - the folder's `ProductionCandidate == true`;
  - `AuthorizedPlace` (stamped by the installer from the Edit place name) names Expansion1Review;
  - the pcall'd `CandidateConfig` returns exactly `{ Authorization = "Expansion1Review",
    Storage = "LocalOnly", Flags = { SpringVault, AdventureRewards, BroadwaveOrdinary } }`, all
    booleans, with no other keys.

`StorageGate` is the only `src/` module that references `DataStoreService` (a static check in
`candidate-storage.spec` enforces this). In `LocalOnly` and `Refused` it never even calls
`GetService("DataStoreService")`. It counts and refuses every attempt.

| Consumer | LocalOnly behaviour |
|---|---|
| DataService (`PlayerData_v1`): load, autosave, removal release, BindToClose | In-memory from Init. No acquisition, no `__probe`, no `UpdateAsync`. `StorageMode() == "LocalOnly"`. |
| TrophyPendingStore (`TrophyPendingGrants_v1`), AdventureSettlement outbox (`AdventureRewardIntents_v1`) | Memory outbox. No acquisition. |
| MonetizationService (`PurchaseHistory_v1`) | Checks before acquiring. This also fixes the acquire-before-check order for every mock case. |
| LeaderboardService (all-time and weekly OrderedDataStores, write budget) | No acquisition, no budget call, no requests on refresh or removal. |

Candidate flags are applied in `AdventureFlags.luau` at require time, only when the profile is
`LocalOnly`. The shipped source still reads `= false` three times. No cached flag table is changed
during Play.

**Studio result:** the acceptance session ran its whole length with
`StorageGate.Counters() = { Acquired = {}, Refused = {} }`. No consumer even tried. The Studio
refusal run (`evidence/production-candidate/refusal-run.md`) started nothing.

## 3. Provisioning (reproducible)

1. In this worktree, run `python -X utf8 tools/expansion1/inject-production-candidate.py --write-manifest <file>`.
   It serves on 127.0.0.1:34874, GET only, and serves only files under `src/` and
   `tools/expansion1/production-candidate/`. The manifest records:
   - the full commit and a dirty flag;
   - every served file with its sha256;
   - the CandidateConfig source;
   - the storage profile;
   - the parked paths and the service properties.
2. In the Expansion1Review Edit DataModel, run `tools/expansion1/install-production-candidate.luau`
   (command bar, or Studio MCP `execute_luau`).
   - It refuses unless the place is `Expansion1Review.rbxlx` with PlaceId 0 and GameId 0, Play is
     stopped, and nothing is installed yet.
   - It parks Codex's dedicated review boot (`AdventureReview` ×2, `Adventure`,
     `SpringVaultClient`, `ExpansionReview`) and the old `Shared` in
     `ServerStorage.PreProductionCandidateBackup`, each tagged with its original path. Nothing is
     deleted.
   - It applies the production Workspace and SoundService properties, recording the old values.
   - It installs production `Server` (Main **enabled**, mapped as `default.project.json` maps it),
     `Shared`, `Client`, `ProductionCandidate.CandidateConfig`, and a small non-interactive label
     ("LOCAL CANDIDATE: in-memory storage only; rewards are local simulation") that logs each
     `AdventureOutcome` payload.
3. Press Play.
4. Afterwards, run `tools/expansion1/uninstall-production-candidate.luau`. It removes the
   candidate, restores every parked instance and property, and leaves one undo waypoint. It was
   verified twice: Codex's review scripts came back with the same source lengths, streaming back
   off, and ServerStorage empty. The place file was never saved.

Limits of the injected place:
- Studio refused `StreamingMinRadius`, `StreamingTargetRadius`, `StreamingIntegrityMode`,
  `StreamOutBehavior` ("not a valid member") and `Lighting.Technology` (capability) from plugin
  context. So `StreamingEnabled` was on but with default radii, and the arena was already
  replicated at spawn (214 parts).
- Expansion1Review is shared with Codex, which was using it during this session; its runtime
  sources changed between my first and second inspection. The candidate was installed only for
  this session's runs and removed afterwards.

## 4. Acceptance run on `470465f` (single client, Expansion1Review, local-only memory)

Evidence: `evidence/production-candidate/`, with screenshots `01`–`09`, `final-snapshot.json`,
`intent-log.txt`, `install-acceptance.json`, `manifest-acceptance.json`, `refusal-run.md`
and the test logs. A rehearsal on `56e2bbf`, before the q_pip merge, is kept as
`rehearsal-56e2bbf-*`. That play session's in-memory data was discarded, and the acceptance run
started from a fresh save.

| # | Step | Input | Server-observed result |
|---|---|---|---|
| 0 | Boot | Play | `[CandidateProfile] LOCAL-ONLY CANDIDATE …`; flags from config; runtime started; fresh save: 0 coins, `toy_shovel`, no certs, licenses, finds or quests; `CanEnter=false CanTrial=false` |
| 1 | New-player refusal | walk to hatch (assisted nav), hold E | Truthful refusal toast; stayed on the beach (`01`) |
| 2 | Dig, excavate, scan | mouse clicks on sand, tap timing game, **T** | Server recorded deposit variant `bottle_cap/Large` from a "DIG IT OUT" excavation; scanner used ("DIG DOWN HERE") |
| 3 | Sell | production **Sell** button | +20 coins; `daily_sell_10` Progress 1 → `CanEnter=true` (catch-up: sale + deposit) |
| 4 | Earn, then buy a priced shovel | dig; Sell button; **E** at the Shovel Shop counter; click the 30-coin button | `OwnedShovels.garden_trowel`, equipped → `CanTrial=true` (`02`) |
| 5 | Entrance | hold E at the hatch | Arrived next to Mara with the arrival toast (`03`) |
| 6 | Pip trial | E on Pip; **Z** equips the loan through the shared `Dig_Broadwave` "Broadwave (loan)" button; hold **Q** 1.3 s at 5.5 studs from the patch; E ×3 on the targets | Trial `Wave=true`, `Cleared=3`; **PipQuest granted `ToolLicenses.tool_broadwave = { Source="q_pip", ReceiptId="quest:q_pip" }`**; licensed tool issued at once (`04`). A first Q at 9.7 studs was correctly refused, being outside the 8-stud corridor. |
| 7 | End trial | click "End trial" | Loan removed; **the exact original tool, Garden Trowel `[garden_trowel]`, re-equipped**; player at `SURFACE_RETURN` (-112, 1029, 76) |
| 8 | Licensed controls on the beach | **Z** (shared button reads "Broadwave"), hold **Q** on the dig strip | Ordinary sand 30 → 33.75 through `ResolveTool` and the dig bridge (`05`, `06`); **Z** again stowed it and re-equipped the Garden Trowel |
| 9 | Mara Join / Begin | E on Mara; click **Join**; click **Begin** after its 4 s countdown | Intents `Talk`, `Join`, then `Start` + `Ready` sent by the Begin callback itself; Phase Active |
| 10 | Anchors, latch, route, ball | E ×6 on each of three anchors; E on the latch; E on the left channel; E on the ball | Stage outcomes: `excavation` +6, `vault_open` +6; attached, WalkSpeed 10 (`07`) |
| 11 | Riding in the pocket | **V** while hauling | No ride spawned, not seated (see the limits in section 5) |
| 12 | Gates and ending | walked the left channel (assisted nav) | 3/3 gates; final `Accepted`: +48 coins, trophy `landmark_spring_vault`, stand, `cert_crew`, `q_mara` credit, receipts `adv:` and `trophy:` (`08`) |
| 13 | Automatic return | none | Back at `SURFACE_RETURN`, WalkSpeed 16, loan removed, Garden Trowel equipped, licensed Broadwave stowed (not auto-equipped) |
| 14 | Ordinary digging | mouse clicks on sand | Sand 33 → 40; runtime panel gone (`09`) |
| 15 | Refusal run | AuthorizedPlace set wrong in Edit, then Play | `REFUSED … Nothing was started`; no remotes, world or leaderstats (`refusal-run.md`) |

Per-player outcomes on this client: four `AdventureOutcome` payloads (excavation, vault_open,
Final, and the empty `ball_return`), all `State = Accepted`, `Status = Saved`. **Here "Saved"
means saved to the in-memory store: these are local simulation, not durable rewards.**

## 5. Real, assisted, mocked and memory simulation

| Kind | What |
|---|---|
| **Real Studio input** (keyboard and mouse delivered to the client by Studio MCP) | E (hatch, Pip, targets, Mara, anchors, latch, route, ball, shop counter), Q hold and release, Z equip and stow, T scan, V ride, mouse clicks on sand, the excavation timing game, Sell, Shop buy, Join, Begin, End trial. No Intent or remote was fired from a script. |
| **Assisted** | Walking: Studio MCP character navigation moves the real Humanoid to a point. This is not uncoached play. Shop and runtime-panel clicks were aimed by the button's instance path, because coordinate clicks were hitting the Studio chat window or the action bar; the click itself is a normal mouse click. |
| **Read-only observation** | A server Script, `CandidateReadOnlyProbe`, published a JSON snapshot. `CandidateIntentLog` listened to Intent. Neither writes game state. Both were added during Play only. |
| **Earned in play, not seeded** | Sale record, deposit variant, coins, bought shovel, Pip license, stage and final settlement. No save field was written by a script; no flag table was changed during Play. |
| **Account entitlement (real, not save data)** | The Studio account owns the experience's game passes, according to `UserOwnsGamePassAsync`, a read-only Marketplace lookup: VIP, Sell Anywhere, double sand, and others. So selling worked from the Sell button anywhere, and sand gain had a 2.5× multiplier. This is not a pass-less new player. |
| **Memory simulation** | All persistence: player save, both outboxes, purchase history, leaderboards. The coins, trophy, stand, cert and license exist only for the Play session. |
| **Mock only** | Stream-out and pre-replication start (`production-wiring.spec -a client-stream`); ride refusal from the pocket with a rideable pet (`pip-quest.spec`); invitation toast (`adventure-entry.spec -a invite`); every refusal case and the shutdown and removal storage paths (`candidate-storage.spec`). |
| **Not done** | Two clients, devices (phone, controller), real streaming radii, rejoin, live DataStores, uncoached flow. |

Limits of specific checks:
- **Pre-replication and stream-out in Studio:** not shown. The arena was already replicated at
  spawn, and the radius could not be lowered from plugin context. Covered by the mock only.
- **Ride check in Studio:** a new-player save has no rideable pet, so the refusal seen in Studio
  cannot tell the pocket guard apart from "no rideable pet". The guard is proven in the mock,
  which includes a control case showing the old bypass.
- **Invitation:** not observed. It needs the 7-step tutorial finished, and this player stopped
  at step 6 (dig 20 m, then hatch an egg).
- **Deposit evidence:** the deposit that unlocked entry came from ordinary digging into a
  buried find, not from the scanner. Catch-up cannot tell the two apart (known limit).

## 6. Findings from the run

Codex-owned (runtime and client presentation):
1. **The runtime panel shows on the beach with a licensed Broadwave in hand** (`05`). "Optional:
   talk to Mara… Join / Ignore / Options" covers the objective pill and depth meter. Starting the
   runtime away from the arena is intended, but the panel should be arena-only. Keep the touch
   charge control.
2. **Trial completion copy.** The runtime still says "No permanent license or trial coins awarded
   in review" as the license is granted.
3. **The tutorial guide arrow overlaps the panel header in the arena** (`04`, `08`).

Owner or joint decisions:
4. **"End trial" lifts the player to the beach.** The runtime's restore uses `ReturnFrame`, so
   the player re-enters through the hatch to join Mara. Codex's sequence expected a return to
   the main adventure through Mara. Should trial-only exits stay in the pocket?
5. **"Saved" on the outcome card in LocalOnly.** It is truthful for the store in use, but it
   reads as durable. The candidate label covers it. Should the card say "local" when
   `CandidateStorage` is set?
6. **The Studio chat window covers the top-left Shop and Index buttons.** Coordinate clicks there
   reached chat. Check the live HUD with chat expanded on small screens.
7. With a loan in hand and no arena scene, Q does nothing at all (neither charge nor surface).
   Rare, because loans exist only in the pocket.

## 7. Gates

**Closed by this work:**
- Explicit fail-closed local-only storage with zero acquisition (Studio and mock), and refusal
  outside the authorized place (Studio and mock).
- The controller adopts `Start(remotes, nil)` (mock), with legitimately licensed controls on the
  beach (Studio).
- A legitimate permanent Broadwave grant through q_pip, server-validated and idempotent (Studio
  and mock).
- Riding out of the pocket refused (mock).
- A reproducible candidate with the production lifecycle, server candidate config, and normal
  new-player data.
- Sale and deposit eligibility and the bought-shovel trial prerequisite earned in play (Studio).
- New-player refusal, entrance, Pip trial and grant, shared equip and stow (Z), the exact
  original-shovel restore, Mara Join/Begin, the full run, per-player outcomes, automatic return,
  and ordinary digging, all on the final merged tree with real input (Studio, one client,
  assisted walking).

**Still open:**
- Codex: findings 1–3, plus the fallback-prompt line of sight and the Leave reflow, which Codex
  is already working on.
- Leave during active hauling. The runtime Leave button was not pressed mid-haul; the run ended
  by completion.
- Two clients and the late helper, physical devices, real streaming radii and stream-out,
  same-account rejoin, uncoached discovery.
- Live and cross-server durability (`settlement-durability.md`). Nothing here is durable.
- Owner decisions:
  - findings 4–6;
  - the bible's `cert_explorer` versus the q_pip license (decided for q_pip; the 150-coin q_pip
    reward is not implemented);
  - permanent first-sale evidence;
  - whether the hatch should admit trial-only players;
  - the kill-switch trigger;
  - how far the rewards flag reaches.

## 8. Tests on the merged tree (`470465f`)

- Full `tests/run.sh`: **ALL TESTS PASSED** (`evidence/production-candidate/tests-full-suite-470465f.log`).
  New or extended:
  - `candidate-storage.spec`: localonly 40, refusals 179, production 24, production studio 24;
  - `pip-quest.spec`: 75, off 25;
  - `production-wiring.spec -a client-stream`: 40. It fails 13 checks on the old controller.
- Codex specs: spring-vault 22, runtime 47, input 293, return 111, scene 81, presentation 53,
  initial-stream 16, broadwave-dig 24, trophy-contract 24.
- `tools/adventure/audit-claude-candidate.py HEAD`: exit 0.
