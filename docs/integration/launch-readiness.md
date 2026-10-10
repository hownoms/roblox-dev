# Spring Vault launch readiness: settlement contract, truthful local cards, audit fixes, acceptance observer

Branch `claude/spring-vault-launch-readiness`, 10 October 2026, on default `b4e1b14` (Codex PR #41
merged). Draft PR only: **not merged, not published or uploaded, no Studio session and no live
save test this session.** Every `AdventureFlags` flag still ships `false`.

Ownership was kept as agreed. Claude owns boot/controller arbitration, entry, rewards, storage and
catalogs; Codex owns runtime, input and presentation. **No Codex-owned file was edited**
(`src/server/Adventure/*`, `src/client/Adventure/*`, `tools/adventure/*` and Codex specs are
untouched). The Codex runtime was mutated only temporarily, inside a test run, to prove the new
assertions fail; it was restored and the tree is clean (`evidence/launch-readiness/settlement-expectation-mutations.log`).

Earlier findings resolved by Codex PR #41 are not reopened. Its LocalOnly acceptance covered two
consecutive adventures, the q_pip license, shared equip and stow, exact original-tool restoration,
automatic return and Leave while hauling.

## 1. Settlement-durability expectations now follow the External outcome contract

`tests/settlement-durability.spec.luau` had 11 failures (198 passing): obsolete expectations that
the runtime broadcasts `OnCompletion`'s message to every player. The runtime now sends the neutral
`Ball rescued.` only to connected participants of the captured completion context, and each
player's `AdventureOutcome` card is the only reward statement
(`runtime-input-handoff.md`, "Completion contract").

| Was | Now |
|---|---|
| Ana, Ben, Cal and Eli get `Settlement.COMPLETION_MESSAGE` | Ana, Ben (refused watcher) and Cal (late helper) each get exactly one `Ball rescued.` that claims no reward. Eli (never joined) gets no completion line. Nobody is shown the settlement's summary as their own result. |
| Rewards off: every player is told "Rewards are not enabled" | Gus, the only participant, gets one neutral `Ball rescued.`. Ana, Ben, Eli, Cal and Fin get no completion line. No dedicated-review copy appears in any production snapshot. |
| `OutcomeOwner == nil` meant "the runtime keeps its review copy" | `OutcomeOwner == nil` and `OnCompletion` is still supplied (the refusal callback), so the runtime infers External ownership. With rewards off there is no `OnStage`. |
| The review-copy scan printed and never failed (old B1) | It now fails if any production line says "review only", "no permanent" or "no coins" next to an Accepted card, or to anyone after completion. |

Every durability, idempotency, refusal and reward assertion is kept, for example:
- per-player stage and final truth tables;
- exact coin totals;
- the disconnected participant's saved stage coins;
- no grants with rewards off;
- the trophy-failure isolation and outbox drains.

A new check also asserts that a durable store's card carries no local-storage label.

**Mutation proof.** The new expectations fail when the runtime is wrong:
- sending the callback summary instead of `Ball rescued.` gives 7 failures;
- broadcasting completion to every connected player gives 6 failures.

Result: `SETTLEMENT DURABILITY (on): 218 passed, 0 failed` and `(off): 76 passed`.

## 2. LocalOnly outcome cards no longer imply durable saves

A LocalOnly candidate's store is memory, so `Status = "Saved"` is true for that store but read as
permanent ("ADVENTURE REWARDS SAVED"). The fix:

- `AdventureSettlement.deliver` stamps `outcome.Storage = "LocalOnly"` (candidate) or `"Mock"` (the
  Studio in-memory fallback) when `DataService.StorageMode()` is not durable. `State` and `Status`
  are unchanged, so server truth, logs and the candidate's payload log are unchanged.
- `UI/AdventureOutcome` words those cards without "saved":
  - titles: "ADVENTURE REWARDS (LOCAL TEST)", "STAGE REWARD (LOCAL TEST)", "REWARDS NOT CONFIRMED YET";
  - PendingRejoin says "if it loads during this session";
  - every non-refused card ends with "Local test only: not saved, gone when this session ends.";
  - refusal reasons are unchanged;
  - the card still lists what this session granted.
- **Production is unchanged.** Live servers use `StorageMode() == "DataStore"` and never send
  `Storage`, so they keep "ADVENTURE REWARDS SAVED", "SAVING YOUR REWARDS…", "REWARDS WAITING" and
  "ALREADY COLLECTED". An unknown `Storage` value is ignored. `Mock` exists only in Studio
  (`DataService.detectStore`); a live server without DataStores refuses loads.
- **Labels kept:** the candidate's red "LOCAL CANDIDATE…" label, the production-review banner and
  Codex's `SPRING VAULT · Dedicated review` title are all untouched.

Tests:
- `adventure-outcome.spec` 366 checks (was 123). It sweeps every state, status, kind and resolved
  case under both local stores, and checks that the live wording is byte-identical.
- `candidate-storage.spec -a localonly`: a real in-memory final settlement delivers
  `Accepted/Saved` with `Storage = "LocalOnly"`, the non-participant gets no outcome, and no
  DataStore call is made.

## 3. Audit of first-sale/deposit evidence, trial-only entry, flags and kill switch

An independent audit agent read the contract docs and the code, then ran a throwaway mock spec.
Its reproduction is in `evidence/launch-readiness/audit-reproduction.log` and
`audit-scratch.spec.luau.txt`.

### Fixed (demonstrated defects within the documented contract)

**A1. The tutorial find gave catch-up entry with no deposit.** `production-wiring.md` §2 promised
catch-up "cannot admit someone without real sale and deposit history". But the guaranteed first
find (`DiscoveryService`, dig 6 for players who have never found anything) started an excavation
with a rolled Size/Material variant. `Rules.HasDepositEvidence` counts any non-`Normal`/`None`
variant as an excavated deposit.
- **Before the fix:** 24 of 40 fresh saves passed `CanEnter` as `CatchUp` after only the tutorial
  find and one sale.
- **Fix:** the tutorial find now records the plain `Normal`/`None` variants, like an ambient find.
- **After the fix:** 0/40. A real excavated deposit with a rolled variant plus a real sale still
  qualifies.
- New `tests/adventure-evidence.spec.luau` (35 checks) fails on the old code
  (`evidence-on-old-code` section of the log).
- **Side effects:** the tutorial's first find no longer rolls a rare Size/Material variant or the
  extra value that comes with one. The tutorial flow and `client.spec` scenarios still pass.
- **Note for the next acceptance run:** PR #41's fresh player probably qualified through that
  tutorial "Tiny" variant (CONTINUATION.md step 1). A fresh acceptance player must now excavate a
  real deposit with a non-plain variant (about 45% of deposits at base luck) and make a real sale.
  No seeding is allowed.

**A3. The kill switch left settlement enabled after a failed start.** `AdventureBoot.Start`
enables settlement before `SpringVaultService.Start`. If that throws, `Disable()` skipped
`SetEnabled(false)`, because the call sat inside `if runtime`.
- **Fix:** `Disable()` always disables settlement.
- `adventure-evidence.spec -a failstart` (8 checks): after the fix, settlement is `Disabled` after
  a failed start and after an explicit kill switch. Re-enabling in the same server brings the
  runtime, entrance and settlement back.
- Outbox drains don't depend on this flag ("earned grants stay and outbox drains continue").

### Checked and consistent with the docs (no change)

- **Sale evidence** comes only from a real `EconomyService.Sell` (`SellTimes` quest). Pet, ride
  and digger digs never record finds.
- **Rebirth** keeps quests, finds, certifications and licenses, and resets `OwnedShovels`, so
  `CanTrial` is lost unless the Head Start perk applies. Eligibility writes nothing to the save.
- **Trial-only entry:**
  - the hatch admits only `CanEnter`;
  - Pip checks `CanTrial`;
  - there is no other way into the pocket.

  This matches `adventure-entry.md` and `pip-quest-license.md`.
- **Flags:**
  - candidate flags apply only in LocalOnly;
  - `BroadwaveOrdinary` off means no ordinary adapter, licensed tools or PipQuest;
  - loans never authorize ordinary digging (issued-tool registry plus `AdventureLoan`).
- **Kill switch:**
  - the runtime's `Destroy` fires no settlement callbacks;
  - `AdventureEntry.Stop` lifts everyone in the pocket;
  - licensed tools are destroyed;
  - re-enabling works.

### Not fixed: known limit, which needs an owner decision

**A2. Real deposits often leave no evidence.** A real excavation that rolls plain `Normal`/`None`
records nothing distinguishable. That happens about 55% of the time at base luck (P(Normal) 0.62
× P(None) 0.88). So veterans can be false negatives, as can saves migrated from v2, which only
ever hold `Normal`/`None`. The adventure-evidence spec pins this down explicitly. The real fix is
a permanent deposit/sale record, which is owner decision D1 below. No such record was invented.

## 4. Safe support for two-client acceptance and streaming/rejoin checks

There were no Studio operations this session. The tooling is ready for Codex's assigned runtime
acceptance session.

**`CandidateObserver` (new, server).** `tools/expansion1/production-candidate/CandidateObserver.server.luau`
is mapped only by `expansion1-production-candidate.project.json` as
`ServerScriptService.ProductionCandidate.CandidateObserver`. The existing injector and installer
pick it up from the project, with its sha256 in the manifest. It is a committed, reviewable
replacement for the ad-hoc read-only probes injected during earlier Play sessions.

- **Inert** unless Main published `CandidateProfile = "LocalOnly"`, `CandidateProfile.IsLocalOnly()`
  holds and `DataService.StorageMode() == "LocalOnly"`. Outside a candidate it prints `inert` and
  stops (tested in production modes).
- **Read-only by construction.** It requires the services the game already loaded; it runs in the
  server's own module cache, unlike the command bar. It then only reads:
  - `DataService.IsLoaded/Get` (copies a few fields);
  - the pure `AdventureEligibility.Rules` on the loaded save;
  - `StorageGate.Counters`;
  - `AdventureBoot.Runtime().Event()`;
  - `AdventureEntry.InArena/InPocket/WasInvited`;
  - `AdventureSettlement.OutcomeSent` (a listener).

  It has no remotes, fires nothing and sets attributes only on its own server-only folder
  (`Observation` JSON plus `ObservationSeq`, once a second). A static check in
  `candidate-storage.spec -a refusals` fails on any save write, grant, settlement or entry/boot
  control, storage, PipQuest/BroadwaveLicense, Fire*, Instance.new, Destroy or reparenting, and on
  any attribute write outside its folder.
- **What it records for acceptance:**
  - per player: joins (rejoin ordinal), loaded state, coins, sand, license, real `CanEnter`/`CanTrial`
    with reasons, certifications, trophies, position, InArena/InPocket, WalkSpeed, held tool,
    ToolId, loan flag, backpack and invited;
  - the event: instance, phase, stage, gate, and every participant's Connected/Present/Left/Ready/Attached/Points;
  - every `AdventureOutcome` payload per player, with `Storage`;
  - storage counters and profile/flags;
  - the streaming properties actually in effect (pcall reads).

  It writes `[CandidateObserver]` console lines for join, load (with eligibility), leave, rejoin
  (with a coins/license/trophies comparison across the same-server rejoin) and each outcome.
- **Tested:** `candidate-storage.spec -a localonly` 56 checks. They cover: participant-only outcome
  logging with `storage=LocalOnly`, real-eligibility logging, leave and rejoin logs with a correct
  coin comparison, continuous snapshots that are all serializable, nothing created in
  ReplicatedStorage, nothing written on players, and zero DataStore calls.

**`CandidateClient` (extended, client).** The label script also logs `[Candidate] stream` lines
when this client's copy of `Workspace.SpringVaultAdventure` appears, disappears or changes part
count by a quarter or more. Each line includes the runtime ScreenGui state and the character
position. This is per-client stream-in and stream-out evidence that the server cannot observe. It
still sends nothing to the server and writes no attributes (static check).

**Limits.**
- Studio refuses `StreamingMinRadius`, `StreamingTargetRadius`, `StreamingIntegrityMode` and
  `StreamOutBehavior` from plugin context (`production-candidate.md` §3). The observer reports
  what is actually in effect; it cannot set them.
- Real-radius stream-out still needs those properties set by a person in the Properties pane of the
  confirmed Expansion1Review Edit DataModel, recorded and restored. Otherwise it remains
  mock-covered only.
- Same-account rejoin is only possible as a Studio local-server leave and re-add. The cross-server
  rejoin of the live game cannot be tested with LocalOnly, by design.

## 5. Studio handoff for Codex's next runtime acceptance session

Codex is assigned the next session. Claude will not operate Studio until Codex records that it is
finished. Never operate the same DataModel concurrently.

1. **Inspect connections first.** Use `list_roblox_studios` / `get_studio_state`. Use only a Studio
   whose open place is confirmed as `Expansion1Review.rbxlx` (PlaceId 0, GameId 0), plus its child
   Server and Client test DataModels. Never touch `DigTheBeach.rbxlx` or a published place.
2. Fetch and check out the frozen commit under test. Run
   `python -X utf8 tools/expansion1/inject-production-candidate.py --write-manifest <file>`, then
   `install-production-candidate.luau` in Edit. `CandidateObserver` is installed with the
   candidate; there is no extra probe to inject. Record the install return value.
3. **Optional streaming radii.** If a person sets streaming properties by hand, record the old and
   new values in the session evidence and restore them before uninstalling. The observer's
   `Streaming` block shows what was in effect.
4. **Two-client run:** Test → Clients and Servers, 2 players. Use fresh profiles with no seeding,
   no eligibility shim and no resolver. Pass criteria, read from `Observation` and the console:
   - **Refusal:** a player without evidence logs `canEnter=false/NoEvidence` and stays on the beach.
   - **Earned entry:** a real excavated deposit (non-plain variant) plus a real sale shows
     `CanEnter=true/CatchUp`. After the A1 fix, the tutorial find alone must not.
   - **Late helper:** client 2 joins Mara after the anchors. Both appear in
     `Event.Participants`. Outcome rows exist only for participants; the helper's final keeps the
     run total. A non-contributor gets `Refused` with a reason.
   - **Bystander:** a never-joined client gets no `outcome` lines and no completion text. Check
     the client console for the absence of `Ball rescued.`.
   - **Cards:** every outcome row has `storage=LocalOnly`, and the on-screen card reads
     "(LOCAL TEST)" with the local note. Nothing says "SAVED".
   - **Streaming:** each client's `[Candidate] stream` lines show the arena arriving before or
     while the player enters, and (with real radii) leaving once they are far away.
   - **Rejoin (same server):** close one client's player and add it back if the Studio session
     allows. Expect `REJOIN` and a `rejoin check` line with unchanged coins, license and trophies.
   - **Storage:** `Storage.Acquired` and `Storage.Refused` stay `{}` throughout.
5. Stop Play, run `uninstall-production-candidate.luau`, and confirm restoration. Do not save the
   place, publish, upload or run a live save test.
6. Save the evidence under `assets/adventure/verification/<session>/` and record completion in
   `docs/integration/runtime-input-handoff.md`.

## 6. Owner decisions (open; no policy was invented)

- **D1. Permanent sale and deposit evidence.**
  - Today: sale is quest progress, which can reset; deposit is a non-plain variant, missed about
    55% of the time.
  - Should the server write a permanent first-sale and deposit-excavated record, and backfill
    migrated saves?
  - Should scanner-located and dig-uncovered deposits count equally?
- **D2. Trial-only hatch entry.** Should a player with `CanTrial` but not `CanEnter` be admitted
  to reach Pip?
  - Today they cannot, and the arrival toast mentions Pip even to players without `CanTrial`
    (Pip then refuses truthfully).
  - Related: rebirth drops `CanTrial` for players who have not been licensed yet.
- **D3. Rewards-flag scope.** With `AdventureRewards` off and `BroadwaveOrdinary` on, q_pip still
  writes the permanent license. Should rewards-off also refuse the license?
- **D4. Rewards-off player messaging.** With rewards off, participants now see only
  `Ball rescued.` and the objectives line "Rewards and save status are handled separately.", with
  no card at all. Should production send a refusal card ("Rewards are not enabled") or change that
  objectives line? The card is Claude-owned; the objectives line is Codex-owned.
- **D5. Kill switch:**
  - the trigger (admin command or cross-server message);
  - whether lifted players get a message (Codex R3: `Destroy` is silent);
  - whether same-server re-enable is supported, which works in the mock;
  - whether a trial finished within about 1 s before `Disable()` should still be granted (today it
    is refused, matching "refuses new grants").
- **D6.** Whether End trial should return the player to the beach; crews lifted at run end; stage
  pay requiring arena presence (unchanged from `player-flow.md`).
- **D7. Remaining q_pip reward and certification policy.** The 150-coin quest reward and
  `cert_explorer` are not implemented and will not be without an agreed contract.

## 7. Exact remaining launch gates

1. **Two-client final-merged production journey** in Expansion1Review LocalOnly: late helper,
   refusal, bystander, cards and rejoin (procedure §5). Assigned to Codex.
2. **Real streaming radii and stream-out** observed per client. This needs the properties set by
   hand.
3. **Physical devices** (phone touch, controller), short-screen layout, and the tutorial guide
   arrow against the arena panel. Codex.
4. **Production preference integration** for reduced motion and particles. Codex.
5. **Same-account cross-server rejoin and live/cross-server durability.** This needs a separately
   owner-authorized private test place plan (`settlement-durability.md`). Not possible with
   LocalOnly.
6. **Uncoached discovery** and populated-server performance.
7. **Owner decisions D1–D7.**
8. **Joint review** of this PR, then owner merge. No flag is enabled on the basis of mock or
   local runs.

## 8. Verification actually run (worktree, Windows, mock harness)

| Check | Result | Evidence |
|---|---|---|
| Baseline full `tests/run.sh` on `b4e1b14` | TESTS FAILED: the 11 known settlement failures, 198 passed | this record |
| Full `tests/run.sh` after the changes | **ALL TESTS PASSED** | `evidence/launch-readiness/tests-full-suite.log` |
| settlement-durability on / off | 218 / 76 passed | full-suite log |
| adventure-outcome | 366 passed | full-suite log |
| candidate-storage localonly / refusals / production / production studio | 56 / 220 / 26 / 26 | full-suite log |
| adventure-evidence default / failstart (new) | 35 / 8, failing 2 + 2 on the old code | `audit-reproduction.log` |
| Mutation checks of the new settlement expectations | 7 and 6 failures; restored tree 218/0 | `settlement-expectation-mutations.log` |
| Codex specs: spring-vault 22, runtime 52, return 111, input 295, initial-stream 29, scene 81, presentation 66, outcome-owner 85, trophy-contract 24, broadwave-dig 24 | all pass | `codex-specs.log` |
| `rojo build` of default, candidate, production-review and adventure projects; `luau-lsp analyze` of changed sources on the candidate sourcemap; `stylua --check` of changed files | pass | `build-analysis.log` |
| `tools/adventure/audit-claude-candidate.py 25b50e9` (Codex's independent gate check) | exit 0 | `audit-claude-candidate.log` |

Not run: Studio (no DataModel was operated), two clients, devices, real streaming, live
DataStores.

## 9. Independent review

A separate review agent read the diff and reran the targeted specs (all passing). It found no
blocking defects. Fixed after the review:
- **Observer history was unbounded.** It now keeps the latest 20 outcome rows per player with a
  `Dropped` count. Above 100 kB the snapshot leaves out outcome rows and says so; the console
  lines still carry every outcome.
- **Local pending wording.** It now says "+N Coins (not confirmed yet)" (the coins may already be
  in session data). Local PendingRejoin says "if it loads before this test server closes".

Not changed (noted):
- Rewards-off players get no explanation: owner decision D4.
- Local cards can be one line taller (6). The outcome container already let 5-line cards overflow
  its fixed height without clipping.
- The bystander check recognises only the known completion strings.
