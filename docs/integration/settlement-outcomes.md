# Settlement outcomes: handoff

Branch `claude/settlement-outcomes`, based on default `a4167d9`, 9 October 2026. Nothing was
pushed, uploaded or published. Codex's adventure runtime files were not touched.
`docs/TROPHY_INTEGRATION.md` was not edited; this note is for the lead to fold in.

## What changed

1. **The trophy and stand now go through TrophyService only.**
   - `Rewards.Apply` (`src/shared/Rewards/AdventureRewards.luau`) no longer calls
     `Rules.ApplyLandmarkGrant`. It now writes only `Coins`, `adv:` receipts,
     `Certifications` and `AdventureProgress`.
   - First clear and `cert_crew` are decided from `AdventureProgress.FirstClearAt` and from
     whether the cert is already present. They never depend on the trophy.
   - For a final, `AdventureSettlement` calls the new
     `TrophyService.PrepareCompletionContext(context, { CallerSaves = true })`. This is the
     non-yielding form of `SettleCompletionContext`, with the same mapping and the same
     `Eligible` veto. It runs in the same frame as the `adv:` mutation.
   - The trophy keeps its `trophy:` receipt and its own outbox, `TrophyPendingGrants_v1`.
     The coins, cert and quest credit keep `adv:` and `AdventureRewardIntents_v1`.
2. **Nothing yields inside Heartbeat.**
   - `TrophyService.SettleAdventureCompletion` used to do its outbox writes inline for
     players who were not loaded, which yielded. That logic is now split into a synchronous
     `prepare` step plus per-user write closures.
   - The bridge runs those closures in its own spawned jobs. The old yielding APIs still
     behave exactly as before.
3. **One save covers both parts.**
   - Each loaded player gets one `DataService.SaveAsync`.
   - If that save fails, the coins/cert part goes to the adv outbox and the trophy part goes
     to the trophy outbox through the new `TrophyService.QueueGrant(userId, grant)`.
   - A part that is still `Unconfirmed` is retried after 5, 15 and 30 s while the player
     stays in the server.
4. **One drain covers both outboxes.**
   - `TrophyService.SetDrainHandler(fn(player, why))` hands TrophyService's automatic drains
     to the bridge.
   - `AdventureSettlement.Drain` then runs `TrophyService.DrainPending` (now public, returns
     what it acknowledged) and the adv drain, and sends one Resolved outcome per run.
   - Each outbox is acknowledged only after the save that applied it.
   - If new intents land while a drain is already running, the drain runs again.
5. **Per-player outcomes.**
   - New setter `AdventureSettlement.SetOutcomeSender(fn(player, outcome))` and a new
     `OutcomeSent` signal.
   - While a sender is wired, it replaces the `SetNotifier` reward text, so a player never
     gets both.
   - New client card: `src/client/UI/AdventureOutcome.luau`.
6. **Shared-file edits as a patch.**
   - `docs/integration/settlement-outcomes.patch` covers `Remotes.luau` (the
     `"AdventureOutcome"` event), `Main.server.luau` (`SetOutcomeSender` →
     `Net.FireClient`) and `Main.client.luau` (require and start the card).
   - Apply it **after** `docs/trophy-integration.patch`. Its Main.server hunk sits next to
     the `SetNotifier` lines that the trophy patch adds.
   - `tests/run.sh` gains the client-card spec. `tests/trophy-wired.spec.luau` checks
     outcomes when the remote exists, and checks the reward text otherwise.

## Statuses

| Part status | Meaning | Outcome `State` |
|---|---|---|
| `Saved` | In the live save, and that save has been written | Accepted |
| `Queued` | In the live save; the save failed, but the intent is in its outbox | Accepted |
| `Duplicate` | This receipt was already settled; nothing changed | Accepted |
| `Applied` | In the live save; the write is still in flight (never sent: outcomes go out after writes resolve) | Pending |
| `Unconfirmed` | In the live save only; both writes failed. Retried, and the leave save carries it | **Pending** |
| `PendingRejoin` | Not loaded here; the intent is in the outbox for their next load on any server | Pending |
| `Refused` | Not loaded here and not stored (`PendingWriteFailed` / `PendingFull`) | Refused |
| `Ineligible` | Reason: `NoContribution`, `Disconnected`, `Left`, `LowContribution`, `NotPresent`, `EventIneligible` | Refused |

**How the parts combine.** The outcome's `Status` is the weakest of the adv part and the
trophy part. The rank, from weakest to strongest, is Unconfirmed, PendingRejoin, Applied,
Queued, Saved, Duplicate.

If only the trophy part fails (refused, store write failed, or TrophyService disabled), the
coins and cert stay Accepted. In that case `Trophy = false` and
`Reason = "Trophy<reason>"`, for example `TrophyUnavailable`, `TrophyRecordLimit` or
`TrophyPendingWriteFailed`.

## Outcome payload (remote `AdventureOutcome`, server → owner only)

```lua
{
	InstanceId: string, Kind: "Stage" | "Final", StageId: string?,
	State: "Accepted" | "Pending" | "Refused",
	Status: string,          -- weakest part status (table above)
	Coins: number,           -- granted by this settlement; 0 while PendingRejoin (amount unknown until applied)
	Trophy: boolean, Stand: boolean, Certification: string?,
	Reason: string?,         -- why Refused, or "Trophy<reason>" for a trophy-only failure
	Resolved: boolean?,      -- true: follow-up to an earlier Pending (retry here, or drain on rejoin)
}
```

**When it is sent.**

- One outcome per participant per stage and per final, sent after that player's durable
  writes resolve.
- Ineligible and refused players get an outcome with a reason. The card tells them, for
  example, "No reward: you joined but didn't contribute enough."
- A second outcome with `Resolved = true` follows when a Pending outcome becomes Accepted.
  That happens either when a save retry succeeds here, or when the drain runs on their next
  load on any server.
- Drained Duplicates produce no outcome, because the player was already told.
- The card replaces an earlier card for the same run, keyed on
  `InstanceId|Kind|StageId`. At most 2 cards are on screen. Only `Accepted` is ever worded
  as saved.

## Evidence (headless mock, Windows, luau 0.640)

**Without the patches:**

| Spec | Result |
|---|---|
| util | 8 |
| smoke | 2,212 |
| smoke (Studio mode) | 2,179 |
| trophy | 312 |
| adventure-settlement | 275 (up from 153) |
| adventure-outcome (client) | 22 |
| adventure-trophy-contract | 24 |
| persistence-boot | live and Studio pass |
| client | 1,464 |
| 7 tutorial scenarios | all pass |

**With both patches applied in a scratch copy** (`git apply --check` clean for each, applied
in order): trophy 315, adventure-outcome 23, trophy-wired 28, and every other spec
unchanged and passing.

**Static checks:** `luau-lsp analyze` in strict mode shows only the two existing
RewardsService deprecation warnings. StyLua is clean on the changed files. The Rojo build
succeeds.

**New checks in adventure-settlement.spec:**

- The adv rules never write a trophy, the stand or a `trophy:` receipt.
- First clear and cert are granted even when the trophy is already owned.
- Unrelated `RewardReceipts` keys, other cosmetics, coins from elsewhere, shovels and pets
  survive.
- Exactly one `TrophyGranted` per player, under the `trophy:` receipt.
- Outcomes cover: solo, crew, watcher, disconnect, replay, trophy disabled then repaired on
  the next clear, Queued (both outboxes), Unconfirmed shown as Pending then Resolved, a
  pending trophy-only part, PendingRejoin in both outboxes, and an adv-only or trophy-only
  write failure.
- Shutdown mid-flight: BindToClose holds until both slow outbox writes land.
- On a fresh second mock server: the shutdown-time intents apply exactly once, with one
  Resolved outcome and none on a rejoin. A crash between save and ack on both outboxes
  re-applies as a Duplicate with no outcome. A drain whose save fails acknowledges nothing,
  and the next load acknowledges.

**Mutation run: 11 of 11 killed.** Each of these mutations makes the spec fail:

- The adv path granting the trophy, either through Rules or as a raw record.
- The bridge settling the trophy twice.
- A failed save not queuing the trophy.
- Unconfirmed mapped to Accepted.
- The trophy part ignored when combining outcomes.
- cert_crew tied to trophy ownership.
- Either drain acknowledging before its save.
- The drained outcome not sent.
- Shutdown not waiting.

## Not verified

- **Live Roblox DataStores and a real cross-server rejoin.** "Another server" here is a
  fresh mock game that shares only the mock store. Studio API access was deliberately not
  enabled, because it would write to the live save store.
- **A real BindToClose under the 30 s shutdown budget.** In the worst case, both outboxes
  retry with backoff, which can take about 6 s per player. The wait is capped at 20 s.
- **The card in real Studio rendering, on phone layouts, and alongside real toasts and
  reveals.** It was checked headless only.
- **A two-client Spring Vault run with the runtime wired to `OnStage` / `OnCompletion`.**

## Per-player result audit (branch `claude/apf-result`, from default `5897990`)

9 October 2026. Traced with the **real** `SpringVaultService` booted by the real `Main`
(`tests/settlement-durability.spec.luau`; rewards on, rewards off, every flag off) and the
real client card (`tests/adventure-outcome.spec.luau`). Codex's files under `src/*/Adventure/`
were not edited. Nothing was pushed.

**Invariant.** A Pending or Refused result is never shown as a grant. "Saved", "earned", the
unlock lines and a bare "+N Coins" appear only for `State = "Accepted"`, and the server sends
Accepted only once the grant is durable: the save holding it was written (`Saved`), or its
intent is in the outbox (`Queued`), or it was already settled (`Duplicate`).

### Truth table: rewards ON (`SpringVault` + `AdventureRewards`)

What each client sees at the end of a run. The status line is the runtime's `send(player,
message)`, shown for 4 s. The objective line is the runtime's snapshot `objective`, sent
every second while the run is `Resolving` (about 12 s).

| Who | Outcome card(s) | Runtime status line (to everyone) | Runtime objective line | Server state |
|---|---|---|---|---|
| Full contributor | 3 × "STAGE REWARD SAVED +6", then "ADVENTURE REWARDS SAVED +42, trophy, stand, cert" (Accepted/Saved) | `COMPLETION_MESSAGE` | "Adventure complete. Review only; no permanent rewards." **Contradicts the card (B1)** | 60 coins, trophy, stand, cert in the written save |
| Late helper (contributes) | +6 for vault and ball, final +48 | same | same contradiction (B1) | 60 |
| Watcher (0 points) | Refused `NoContribution` × 3, final Refused `LowContribution` | same | "Review only" (accidentally true) | nothing |
| Disconnected after contributing | Accepted +6 while connected; later outcomes not delivered (absent) | not in server | — | stage coins saved, no final |
| Left the adventure | Refused `Left` (if still in the server) | same | non-joined objective | stage coins earned before kept |
| Bystander (loaded, never joined) | none | `COMPLETION_MESSAGE` (claims nothing) | "Optional: talk to Mara to join, or Pip to try Broadwave." | nothing |

Failure modes (direct boundary calls through Main, plus `adventure-settlement.spec`):

| Case | Card | Server state |
|---|---|---|
| Save fails, outbox ok | Accepted/Queued "…SAVED" | live save + outbox intent (durable) |
| Save and outbox fail | Pending/Unconfirmed "SAVING YOUR REWARDS… +N Coins (not saved yet)", then a Resolved card on a successful retry | live save only; retried; one more outbox attempt after a leave |
| In the server but not loaded | Pending/PendingRejoin "REWARDS WAITING: Not added yet…" (**was "REWARDS SAVED FOR LATER", fixed**), then a Resolved card from the drain | both intents in the outboxes |
| Not loaded, outbox write fails | Refused "Your reward couldn't be stored…" | nothing |
| Trophy display throws | Accepted/Saved with the trophy (F5) | trophy saved |
| Trophy part throws or TrophyService disabled | Accepted coins + cert, plus "Trophies are paused right now: no trophy this time." | coins + cert saved, no trophy |
| Trophy outbox fails (not loaded) | Pending + "The trophy couldn't be stored…" | adv intent queued only |
| Ineligible | Refused with the reason | nothing |
| Settlement disabled (`SetEnabled(false)`) | stage: no card (warning only); final: none, everyone gets `REFUSED_MESSAGE` | nothing new; in-flight writes still finish and are told once |
| Kill switch `AdventureBoot.Disable()` mid-run | runtime destroyed; no completion; participants told nothing (R3) | stage cards already sent stay true |

Live state that is not a reward message: the coin HUD and the camp display follow the live
save as soon as a grant is applied, before its durable write. Neither says "saved".

### Truth table: rewards OFF, and every flag off

| Mode | Cards | Runtime copy | Server state |
|---|---|---|---|
| `SpringVault` on, `AdventureRewards` off (real runtime) | none; `OnStage` is not wired | everyone: "Adventure complete. Rewards are not enabled on this server."; objective "Review only; no permanent rewards." (true here) | nothing granted; `runtime.Settled == false` |
| Every flag off (shipped) | none | runtime not started | nothing |

### Violations found and fixed (Claude side)

1. **Pending card worded as saved.** `AdventureOutcome` titled a `PendingRejoin` card "REWARDS
   SAVED FOR LATER", which reads like the Accepted "…REWARDS SAVED". The intent is queued, not
   granted, and the player is usually still in this server while their save loads. It is now
   "REWARDS WAITING / Not added yet: they'll be added when your save loads, here or the next
   time you join."
2. **No client guard on Status.** The card now words an `Accepted` payload whose `Status` is not
   `Saved`, `Queued` or `Duplicate` as Pending. The server never sends one; this is defence in
   depth.
3. **Silent test probe.** PR #35 changed the runtime text from "REVIEW ONLY: …" to "Review only;
   …". The spec's case-sensitive R1 probe stopped printing, so the contradiction was no longer
   reported. It is replaced by a case-insensitive capture of every runtime line each client
   receives while `Resolving`, compared against that client's final card.

Not changed: a Pending payload still names in-flight `Trophy` / `Certification` (the card
never lists them, and `adventure-settlement.spec` relies on it). A `Duplicate` from a repeated
`OnCompletion` is still reported Accepted without a new save (documented Low in
`settlement-durability.md`).

### Boundary contract (after PR #35)

PR #35 changed only copy and objective text in `SpringVaultService`. The stage observation
and the completion context are unchanged, so the adapter needed no fix. The durability spec
now captures, from the real runtime, every context passed to `SettleStage` and
`SettleCompletion`, and asserts:

- the head fields `BoundaryVersion`, `EventInstanceId`, `EventId`, `LandmarkId`, `RegionId`,
  `CompletedStages` and `Participants` match the reward table;
- the stage participant fields `UserId`, `Points`, `ObjectiveIds`, `Connected` and `Left`;
- the final participant fields `UserId`, `Points`, `ObjectiveIds`, `Eligible` and
  `ActiveSeconds`, plus `Success`;
- the contexts are frozen, each stage arrives exactly once, and exactly one completion arrives
  (the runtime's own `LastCompletion`);
- every report is `Ok`, and `TrophyService.PrepareCompletionContext` accepts the real context:
  contributors `Granted`, the watcher `Ineligible`.

An outcome monitor on `OutcomeSent` runs across the whole spec. It checks that every Accepted
outcome is already in the written save or in its outbox at the moment it is told.

### Blockers for Codex (runtime copy; not edited here)

**B1 (High, blocks enabling `AdventureRewards`). Review copy contradicts the reward card.**
When `AdventureRewards` is on, a contributor's card says "ADVENTURE REWARDS SAVED +42 …" while
the runtime tells the same player the following:

| File:line (at `5897990`) | Exact string | When / to whom |
|---|---|---|
| `src/server/Adventure/SpringVaultService.luau:363` | `"Adventure complete. Review only; no permanent rewards."` | snapshot `objective`, every second while the run is complete, to joined participants |
| `src/server/Adventure/SpringVaultService.luau:370` | `"REVIEW ONLY  -  no coins, certifications or permanent trophies are granted."` | snapshot `objectives[4]`, every snapshot, every player (the current client shows it only if `objective` is not a string) |
| `src/client/Adventure/SpringVaultClient.luau:157` | `"SPRING VAULT · Review"` | panel header, always |
| `src/client/Adventure/SpringVaultClient.luau:159` | `"Help uncover a springy surprise · about 5 minutes. Review build: permanent rewards are unavailable."` | status line until the first snapshot |

Suggested fix: a start option that says an external outcome card owns reward messaging.
`AdventureBoot.Options` already passes it whenever `AdventureRewards` is on:

```lua
SpringVaultService.Start({ ..., OutcomeOwner = "External" })
```

When `opts.OutcomeOwner == "External"`:

- the completed objective becomes `"Adventure complete!"`, or `"Adventure complete! Your reward card shows your result."` for joined players;
- drop the `REVIEW ONLY` entry from `objectives`;
- add `data.outcomeOwner = "External"` to the snapshot, so the client:
  - shows the header `"SPRING VAULT"`;
  - shows the status `"Help uncover a springy surprise · about 5 minutes."` with no review
    clause. This applies to the initial label as well, which can stay neutral until the first
    snapshot.

When the option is absent (the review place, or `AdventureRewards` off), keep today's copy.
Today's copy is true there, as the rewards-off run shows.

Acceptance: `luau tests/settlement-durability.spec.luau` prints `runtime review copy
contradicting an Accepted card: 0 line(s)` and no `BLOCKER B1` lines. That check is advisory
today, so Codex's fix can land on its own. Turn it into a hard check once it lands.

**B2 (Low).** Other review-era copy that reaches production players. These strings are true
but worded for the review build:

- `SpringVaultService.luau:457`: `"Mara's adventure unlocks after a sale and scanner deposit. Review uses an explicit starter loan."`
- `SpringVaultService.luau:646`: `"Pip: Excellent! Broadwave trial complete. No permanent license or trial coins awarded in review."`

Under `OutcomeOwner = "External"`, suggested:

- `"Mara's adventure unlocks after your first sale and scanner deposit."`
- `"Pip: Excellent! Broadwave trial complete."`

**Unchanged:** R2 (completion message to everyone) and R3 (kill switch and failure cleanup
tell participants nothing) from `settlement-durability.md` still stand.
`SpringVaultService.luau:956` (`"Completion handoff failed; no rewards confirmed."`, sent to
everyone if `OnCompletion` throws) is truthful, and our `OnCompletion` does not throw.

### Evidence (headless mock, Windows)

| Spec | Result |
|---|---|
| settlement-durability (runtime on, in-process) | 209 (was 105) |
| settlement-durability `-a off` | 76 (was 53) |
| adventure-outcome (client card) | 122 (was 23) |

Mutations, each killed:

- `Unconfirmed` mapped to Accepted (monitor and existing check).
- An outcome sent before its save (monitor: "durable when told").
- The old "REWARDS SAVED FOR LATER" title (10 failures).
- The client `Status` guard removed (33 failures).
