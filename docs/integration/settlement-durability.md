# Settlement durability audit

Branch `claude/svi-settle`, based on `3e216f5` (the consolidated adventure patch is applied, and
Main boots TrophyService, AdventureSettlement and AdventureBoot with every flag off).
9 October 2026. Nothing was pushed, uploaded or published. No shipped flag was changed.
Studio was not used, and no live DataStore was touched.

The audit drives the real `Main.server.luau` wiring. The new spec,
`tests/settlement-durability.spec.luau`, runs in two modes:

- **Default mode.** It sets `AdventureFlags.SpringVault` and `AdventureRewards` to true *in the
  test process only*, before Main runs. This works the same way as
  `production-wiring.spec -a on`. The real `SpringVaultService` then calls `OnStage` and
  `OnCompletion` and broadcasts the result to every player. The spec checks first that the
  shipped flags are false.
- **`-a off` mode.** It boots with every flag off, which is the shipped state.

## Findings

| # | Severity | Where | Failure | Fix | Test (killed mutation) |
|---|---|---|---|---|---|
| F1 | High (data loss, rare) | `DataService.saveAsync` | A save treated a *missing* lock as its own. Sequence: this server's lock went stale during an outage, another server took the save over, then released it on leave. This server's next autosave or leave save then overwrote the newer save with its older copy (lost coins, purchases). | A save now aborts unless the lock is this session's. Load always takes the lock and every save keeps it, so a missing lock always means another server took over. The player is asked to rejoin. | "a stale cached profile never overwrites a newer save" (M5) |
| F2 | Medium (durability, mixed versions) | `DurableOutbox.Ack` | Every acknowledgement deleted *all* entries this server could not validate. After a publish, old-version servers keep running. An intent written by a newer server (new event, raised `BaseCoins`, new trophy id) was deleted by the player's next drain on an old server. The intent was accepted, then lost. Applies to both outboxes. | Unknown entries are never returned and never count toward the bound. They are dropped only when dead: not a table, no numeric `At`, or older than 90 days. | "outbox acknowledgement keeps intents from a newer server version" (M4) |
| F3 | Medium (truthfulness) | `AdventureSettlement.OnCompletion` | The runtime broadcasts the returned message to **every** player in the server. "Rewards are on their way." reached refused watchers, ineligible players and bystanders. | Neutral `COMPLETION_MESSAGE`: "Adventure complete! Crew members: your reward card shows what you earned." The refusal text now says stage rewards already earned are kept. | Real runtime: every recipient's snapshot message claims no reward (M1) |
| F4 | Medium (truthfulness) | `Rewards.FinalDecisions` | Any runtime veto was reported as `EventIneligible`, worded "you weren't in the crew at the finish". That was wrong for a watcher who stayed to the end with 0 points. | When our contribution rule also fails, the reason is the contribution one (`LowContribution` / `NotPresent`). `EventIneligible` is kept only when our rule alone would pass. | Watcher's final reason (M2). Two `adventure-settlement.spec` expectations were updated to the truthful reason. |
| F5 | Medium (robustness) | `TrophyService.applyGrant` | The camp display refresh (`AfterGrantApplied`: `Display.Show`, pad hand-over, status) ran unguarded inside the grant. A throw there (camp code is under concurrent edit) aborted `PrepareCompletionContext`, so the whole final failed for the rest of the crew. The runtime then said "no rewards confirmed" while some trophies were already in live saves. | `pcall` around the display side effects. The grant result always returns. | "display throws during the grant" (M3) |
| F6 | Medium (robustness) | `TrophyService.DrainPending` | Any throw inside the drain left `draining[userId] = true` forever. No later trophy drain could run for that user on that server. | The body runs in a `pcall`, and the flag is always cleared. | "a throw inside the trophy drain does not wedge later drains" (M9) |
| F7 | Medium (durability) | `AdventureSettlement` drain | If the outbox read failed at load, intents waited until the player's *next* join, possibly days later, after they had been told "saved". If the drain's save failed, the retry re-applied the intents as Duplicates, and the player was never told. | (a) A failed read or save schedules an in-session retry (`RetryDelays`, 3 tries). (b) Items applied by a drain whose save failed are remembered and announced once a later drain acknowledges them. `TrophyService.DrainPending` now returns `(acknowledged, retry, unacknowledged)`. The first return value is unchanged. | "outbox unreadable at load" (M6). "drain save fails, retry ... tells the player" (M7) |
| F8 | Low (durability) | `retryUnconfirmed` | Case: a grant is `Unconfirmed` (save and outbox both failed) and the player leaves. Only the leave save could still carry it. If that save also failed, the grant was lost. | On waking after a leave, the retry makes one more outbox attempt. If the leave save landed, the intent becomes a Duplicate on the next load. | "last outbox attempt after the leave" (M8) |
| F9 | Low (robustness) | `AdventureSettlement.settle` | A throw in the trophy part, or in one player's apply, aborted everyone's settlement. | `pcall` around `PrepareCompletionContext`: the trophy part reports `TrophyUnavailable` and the coins and cert stand. A per-player `pcall` turns one bad save into that player's `Refused / SettlementError`. | "a throw in the whole trophy part" (M10). The per-player guard has no test, because no save shape makes `Rewards.Apply` throw. |

**Mutation run: 10 of 10 killed.** Each fix was reverted on its own. The full spec set was
re-run against each reversion and failed every time. The script was a scratch file outside the
repo.

### Checked and fine

- **Unrelated save fields.** Settlement never touches them. Checked through Main: coins from
  elsewhere (1000 + exactly 60), `OwnedShovels`, `Pets`, other `Cosmetics`, `ToolLicenses`,
  `Settings`, `Quests`, `FindVariants`, `cert_rookie`, a `quest:` receipt and an older `trophy:`
  receipt.
- **Receipt namespaces.** Pruning touches only `adv:` (Rewards) and `trophy:` (Trophies.Rules)
  keys. Outbox `Ack` removes only listed receipt ids, plus dead entries since F2.
- **Unloaded or failed profiles.** Nothing grants into a profile that is unloaded or failed to
  load. `applyLive` needs a DataService session, and a failed load kicks without creating a
  session or resetting the save. A released session is gone before its leave save, so a
  settlement in that window takes the outbox (`PendingRejoin`) path.
- **Studio without API access.** The save store and both outboxes are in memory. "Saved"
  outcomes in Studio do not survive the session, which is expected.
- **Same-server rejoin.** It waits for the previous leave save (`releasing`), so an older cache
  cannot be reused.
- **Stage reconciliation.** The real runtime run pays 60 in total to a full crew member
  (6 + 6 + 6 + 42) and to a late helper (6 + 6 + 48). A failed (abandoned) run keeps 6 and
  grants no final, cert, trophy or clear.
- **Kill switch mid-settlement.** In-flight writes complete and the player is told once. New
  stage and final settlements are refused truthfully. Outbox drains continue.
- **Duplicates and retries.** Every receipt is idempotent. A UpdateAsync retry after a commit
  that timed out is a no-op, because the receipt is already stored.

### Left as is (documented)

- **Low: `Duplicate` from a repeated `OnCompletion` is reported Accepted without a new save.**
  The runtime sends each completion once (`completionSent`), so this needs a second call by
  the caller.
- **Low: receipt TTL of 30 days.** An outbox intent drained more than 30 days after its run's
  stage receipts were pruned could over-pay by up to 18 coins. That needs a `Queued` intent
  that sat unapplied for a month.
- **Low: card wording.** A same-session Resolved follow-up is titled "REWARDS FROM YOUR LAST
  ADVENTURE". `TrophyUnavailable` after a failure reads "Trophies are paused".
- **Info: settlement stays enabled with every flag off.** That is harmless, because nothing
  calls it. The drain runs on every join, at 2 outbox UpdateAsync reads per join.

## Outcome truth table (real runtime through Main, mock store)

| Participant | Stage outcome | Final outcome | Granted |
|---|---|---|---|
| Full contributor, connected | Accepted +6 per stage | Accepted/Saved +42, trophy, stand, cert | 60 total, trophy, stand, cert |
| Late helper (joins after excavation, contributes) | none for excavation (not a participant), Accepted +6 vault and ball | Accepted +48 | 60 total |
| Watcher (joined, ready, 0 points) | Refused `NoContribution` ×3 | Refused `LowContribution` (was `EventIneligible`, F4) | nothing |
| Disconnected after contributing (held, never back) | Accepted +6 while connected; later stages `Disconnected` (not delivered: absent) | `EventIneligible` / `LowContribution`, not delivered | stage coins saved |
| Left | `Left` | vetoed | stage coins earned before |
| Bystander (loaded, never joined) | none | none | nothing |
| Everyone in the server | — | broadcast `COMPLETION_MESSAGE` (claims nothing) | — |
| Save write failed, outbox ok | Accepted `Queued` | Accepted `Queued` | in live save + outbox |
| Save and outbox failed | Pending `Unconfirmed` → Resolved on retry | same | live save; outbox retried after leave (F8) |
| Not loaded here, outbox ok | Pending `PendingRejoin` → Resolved by the drain on their next load | same | on next load anywhere |
| Not loaded, outbox failed | Refused `PendingWriteFailed` | same | nothing |
| `AdventureRewards` off | no stage settlement wired | runtime gets `(false, "Rewards are not enabled on this server.")` | nothing; no outcome sent |
| Kill switch before final | stages already told stay true | no final; new settlements `Disabled` | stage coins kept |
| Kill switch mid-write | in-flight writes complete and are told once | `REFUSED_MESSAGE` for a later completion | accepted grants land |

## Durability matrix

| Property | Evidence | Class |
|---|---|---|
| Accepted only after save or outbox write | settlement, durability specs | mocked durability (headless mock store) |
| Outbox write failure → Unconfirmed/Refused, never Accepted | durability spec, adventure-settlement | mocked |
| UpdateAsync transient failure / retries | fault injection per store and key | mocked; **live throttling behaviour needs live evidence** |
| Crash between save and ack → Duplicate, then acked | adventure-settlement ("another server") | mocked |
| Drain read or save failure → in-session retry, outcome kept | durability spec | mocked |
| Newer-version intents survive an old server's drain | durability spec | mocked; **mixed-version servers need live evidence** |
| Stale cached profile cannot clobber a newer save | durability spec, simulated takeover on the shared record | mocked; **real cross-server takeover needs live evidence** |
| Unconfirmed + leave + failed leave save → outbox | durability spec | mocked |
| BindToClose: in-flight writes resolve before the 20 s wait | worst case of 5 players with every outbox write failing: **10.4 s** of mock time, excluding real UpdateAsync latency | mocked; **requires a live shutdown test** |
| Shutdown mid-settlement on a real server | none | **requires live shutdown evidence** |
| Real cross-server rejoin and drain on another server | none (a fresh mock game only) | **requires live cross-server evidence** |

Worst case per player during shutdown is the save (4 attempts, 1 s apart), plus the adv
outbox (3 attempts, 1 + 2 s), plus the trophy outbox (3 attempts). That is roughly 9 s plus 10
UpdateAsync round trips, measured against the 20 s settlement wait, the 25 s DataService wait
and Roblox's 30 s cap. Under real throttling a round trip can take seconds. Measure it live.

## Live test plan for the owner

Use a **private test place** with Studio API access or a private server. Never use the
production place: DataStores are per experience, so the test place's stores are separate. Set
the flags only in that place's copy.

**Prep.** Publish this branch to the test place with `SpringVault` and `AdventureRewards` on.
Two test accounts, A and B. Note A's coins.

1. **Normal completion.**
   - A and B run the vault. B watches.
   - Expected: A's card shows "ADVENTURE REWARDS SAVED +42", trophy, stand and cert after three
     "+6" stage cards. B's cards say "didn't contribute". Both see the neutral broadcast.
   - Rejoin A: coins are +60, and the trophy is still there.
2. **Shutdown during settlement.**
   - Add a temporary server-side `task.wait(8)` before `DataService.SaveAsync` in
     `confirmLive` (test place only).
   - Complete a run, then shut the server down immediately from the Creator Dashboard
     (Servers → Shut down) within 2 s of the completion.
   - Rejoin A on a new server: coins +60 exactly once, trophy and cert present.
   - Check the `AdventureRewardIntents_v1` / `TrophyPendingGrants_v1` keys `Pending_<A>` in the
     DataStore manager: empty, or acknowledged after the rejoin.
   - Repeat 3 times. Record the shutdown log timing: `[DurableOutbox]` warnings and how long the
     BindToClose took.
3. **Cross-server rejoin.**
   - With the outbox fault hook below, force A's final to `PendingRejoin`. One way is to kick A
     right after completion, before the save, using a temporary admin command.
   - A joins a *different* server (use a second private server link).
   - Expected: a "REWARDS FROM YOUR LAST ADVENTURE" card, coins applied once, outbox key
     emptied. A third join shows no card and no extra coins.
4. **Session takeover (F1).**
   - Join A on server 1 and note the coins.
   - In the DataStore manager, set `Player_<A>`'s `Lock.Time` back by 1 hour.
   - Join A on server 2. It steals the lock. Earn coins there, then leave.
   - On server 1, force a save with a temporary admin command.
   - Expected: server 1 logs "session lock ... was taken", and the store keeps server 2's
     coins.
5. **Outbox outage.**
   - Temporarily make `DurableOutbox` use a store name the place can't write, for example with
     a forced `error` in `update` behind a test-place-only attribute.
   - Complete a run. Expected: the card shows "SAVING..." or Accepted `Queued`, never
     "SAVED" without a durable write. After removing the fault, rejoin: Resolved once.
6. **Kill switch.** Call `AdventureBoot.Disable()` from the server console mid-run and again
   right after a completion. Stage coins earned stay, and no final is granted after the switch.
7. **Throttling.** With 4 to 6 players, complete runs back to back and watch for
   `DataStoreService` budget warnings. Measure the time from completion to the card.

Remove every temporary hook afterwards. None of them belongs in production.

## Requests to Codex (runtime, not edited here)

- **R1 (Medium, truthfulness).** After a wired completion, the snapshot `objective` still reads
  "Adventure complete. REVIEW ONLY: no permanent rewards granted." The `objectives` list and
  Mara's line ("Review build grants no permanent rewards") say the same. Those statements are
  false once `OnCompletion` is wired. Please make the review wording conditional on
  `opts.OnCompletion == nil`, or take the text from an option.
- **R2 (Low).** The completion message goes to every player, including bystanders. Consider
  sending it to participants only, or offering a per-recipient message callback. Our side now
  returns a message that is true for everyone.
- **R3 (Low).** `Destroy()` (the kill switch) and failure cleanup tell participants nothing.
  Suggested text for participants: "Adventure stopped. Stage rewards you earned are kept."
- **R4 (Low, from L5).** Stage observations still pay participants who are not `Present`. This
  is an owner decision.

## Evidence (headless mock, Windows, luau 0.640)

| Spec | Result |
|---|---|
| util | 8 |
| smoke / smoke (Studio) | 2212 / 2179 |
| trophy | 400 |
| adventure-settlement | 275 |
| trophy-wired | 35 |
| adventure-outcome | 23 |
| adventure-trophy-contract | 24 |
| **settlement-durability (runtime on, in-process)** | **105** (new) |
| **settlement-durability `-a off`** | **53** (new) |
| production-wiring off / on / rejoin / client | 36 / 38 / 13 / 20 |
| persistence-boot live / Studio | pass / pass |
| client | pass |

StyLua is clean on the changed files.
