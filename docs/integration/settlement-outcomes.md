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
