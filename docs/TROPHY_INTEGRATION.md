# Adventure trophies: integration handoff

Branch `claude/adventure-trophies`, prepared 9 October 2026. Scope: permanent adventure
trophies and their camp display (game bible milestone 2 trophy slice, applied to the Spring
Vault). This branch does not implement the Spring Vault adventure, NPCs, Broadwave, anchors,
vault opening, ball routing or effects, which belong to Codex's branch. It does not edit shared
boot files, DataService, Config, Types or Codex's files. The one shared-file change is a single
line in `tests/run.sh` that registers the new spec. Nothing was uploaded or published.

## What is in this branch

| File | Role |
|---|---|
| `src/shared/Trophies/Catalog.luau` | Trophy definitions. Only `landmark_spring_vault`, with source `event_vault`, region `sunshine_shore` and replica `TrophyReplica`. There is no payout or sale field. |
| `src/shared/Trophies/Rules.luau` | Pure rules: save migration/repair, receipts and pruning, the contribution eligibility rule, and camp grid validation. |
| `src/server/Services/TrophyData.luau` | The narrow adapter to the existing `DataService`. It is the only trophy file that touches the save. |
| `src/server/Services/TrophyService.luau` | Server-authoritative settlement API, ownership queries, camp place/remove and remote handlers. |
| `src/server/Services/TrophyCampDisplay.luau` | Builds camps from `Models.Expansion1.TrophyStand()` + `TrophyReplica()` on reserved pads. |
| `tests/trophy.spec.luau` | 227 headless checks. Registered in `tests/run.sh`. |
| `tests/trophy-wired.spec.luau` | 17 checks through the real `Main` with the patch applied. Register it when the patch merges. |
| `docs/trophy-integration.patch` | The exact shared-file wiring, tested (see below). |

## Persistence: no second save system

Trophy state is three new top-level `PlayerData` keys in the same session-locked
`DataService` record (`PlayerData_v1`, key `Player_<UserId>`). They use the names from bible
ch.04:

```
TrophyRecords  = { [trophyId] = { Kind, Source, RegionId, AcquiredAt, ReceiptId, Legacy, ContentVersion } }
CampLayout     = { Placements = { { Id, TrophyId, X, Z, Rot } }, NextId }
RewardReceipts = { ["trophy:<InstanceId>:<UserId>:final:v<RewardVersion>"] = settledUnix }
```

This works without editing DataService. These facts were checked in source and by tests:

- `DataService.sanitize` → `TableUtil.Reconcile` keeps keys the template does not know.
  `saveAsync` writes a deep copy of the whole save. That means the currently published v17
  server also carries these keys through untouched, which makes rollback compatible.
- Saves use the normal autosave, leave and `BindToClose` paths. A settlement also calls
  `DataService.SaveAsync` immediately, because DataService serializes saves.
- The keys replicate to the owner through the existing `DataChanged` deltas, so a future
  camp/trophy UI can read them from the client data mirror.
- Rebirth resets only `Config.Rebirths.Resets`, which does not include these keys. The
  wired spec runs a real rebirth and checks this. The dev-only `/wipe` command resets just
  the template keys, so trophies also survive it.

**Migration.** `TrophyData.Get` runs `Rules.Migrate` once for each loaded save table.

- It adds the three keys to any existing save and repairs malformed values.
- It changes no other key. The tests compare every other field before and after.
- It is idempotent.
- It never deletes an owned trophy id. A non-table record is kept as `{ Repaired = true }`.
  Records unknown to this server, for example from a newer server, are kept as-is.
- It invents nothing. Legacy saves get no adventure trophy, because no legacy evidence of a
  Spring Vault completion exists.
- Invalid camp placements are dropped. That loses a display only, never ownership.

`Config.DATA_VERSION` stays at 3. Bible ch.04 says to introduce DataVersion 4 only when its
whole field set is implemented. When that happens, an optional hook is to add
`[3] = function(d) Rules.Migrate(d, os.time()) end` to DataService's `MIGRATIONS`. That is
safe because the function is idempotent, and the lazy path can stay as a fallback.

**Bounds.**

| Item | Bound |
|---|---|
| Records | 256. New grants beyond that are refused with `Refused/RecordLimit`. Loads never delete records. |
| Layout | 32 placements. |
| Starting trophy slots | 3. |
| Receipts in the `trophy:` namespace | 512 most recent, kept for at most 30 days. |
| Pending offline grants | 64 users × 8 grants. |

Receipt pruning is safe because ownership in `TrophyRecords` is the permanent first-clear
flag.

## Completion API for Codex

**Shortest path for `codex/spring-vault-adventure`** (checked against `e19f508`): pass
`OnCompletion = TrophyService.OnCompletion` to `SpringVaultService.Start` in place of the
review adapter. It takes the frozen `CompletionContext` from
`SpringVaultState.completionContext()` and returns `(accepted, message)`. The message is
broadcast to every player, so it stays generic. `TrophyService.SettleCompletionContext(context)`
returns the full per-player report described below.

The mapping:

| Context field | Becomes |
|---|---|
| `EventInstanceId` | `InstanceId` |
| `Success` | `Outcome`: `true` → `"Completed"`, otherwise `"Failed"` |
| `#ObjectiveIds > 0` | `PresentForObjective` |
| `ObjectiveCompletions` | `#ObjectiveIds` if the player earned points, else 0 |
| `RewardVersion` | Always 1 (not `BoundaryVersion`) |

Both rules must agree before a player is granted. The context's own `Eligible` flag must be
`true`, and since that flag also requires being connected and present, a vetoed player
reports `Ineligible / EventIneligible`. The consequence is that players who disconnected
before completion are vetoed by the runtime and never reach `PendingRejoin` through this
path. That is the runtime's current choice; see open decision 3.

The general API, for any other caller:

```lua
local TrophyService = require(ServerScriptService.Server.Services.TrophyService)

local report = TrophyService.SettleAdventureCompletion({
	EventId = "event_vault",               -- completion context (required, exact)
	LandmarkId = "landmark_spring_vault",  -- trophy entitlement source (required, must match the event)
	InstanceId = instanceId,               -- unique per adventure run, 1..80 chars
	Outcome = "Completed",                 -- anything else is refused: no trophy for failure/abandon
	RewardVersion = 1,                     -- optional integer 1..1000, default 1
	Participants = {                       -- 1..16 entries, unique UserIds; include EVERY admitted player
		{
			UserId = 123,
			Points = 12,                   -- validated contribution points (bible ch.04), finite >= 0
			ActiveSeconds = 95,            -- validated active participation seconds, finite >= 0
			ObjectiveCompletions = 1,      -- validated objectives this player completed, finite >= 0
			PresentForObjective = true,    -- present for >= 1 validated objective completion
		},
	},
})
```

**When to call.** Call it once per run, after Resolving has frozen scoring and snapshotted
contributions, and before cleanup returns or removes players. It is server-only and never
yields. It is safe to call again with the same arguments, for example on a retry.

**InstanceId.** Use something unique across servers and runs, such as
`(game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)) .. ":" .. sequence`
with a per-server sequence number. Bible ch.04 requires a session GUID plus a sequence,
not a timestamp.

**Eligibility.** The service applies bible ch.04's rule itself, so Codex supplies validated
facts rather than a verdict:

- Solo: if `#Participants == 1` and `ObjectiveCompletions >= 1`, the player is eligible.
- Otherwise the player needs `Points >= 5` and, in addition, either `PresentForObjective`
  or `ActiveSeconds >= 30`.
- Presence alone never qualifies.

Codex's assumptions:

- Points follow ch.04: 10 per anchor split among workers, 5 per validated transition, and
  so on. Repeat or presence-only actions earn zero.
- All values come from server-validated actions.
- The participant list includes ineligible spectators, because the solo rule is based on the
  list size.

**Return value.** `SettlementReport`:

```lua
{
	Ok = boolean,
	Error = string?,        -- only when Ok == false; then NOTHING changed for anyone
	EventId, LandmarkId, InstanceId,
	Results = { { UserId, Status, Reason? } },  -- same order as Participants
	ByUserId = { [UserId] = result },
}
```

| Status | Meaning | What to show |
|---|---|---|
| `Granted` | Newly owned. The record and receipt were written in one synchronous save mutation, and a save was requested. | Trophy reward |
| `AlreadyOwned` | Owned from an earlier run or instance. Nothing changed. | Completion only ("trophy already in your collection") |
| `Duplicate` | This exact receipt was already settled, so this is a retry. Nothing changed. | Same as the first response |
| `PendingRejoin` | Eligible but not loaded on this server. Granted if they load here again before shutdown. | Nothing to that player now |
| `Ineligible` | `Reason` is `LowContribution` or `NotPresent`. | No trophy |
| `Refused` | `Reason` is `RecordLimit` / `PendingFull` / `NotLoaded`. Not stored. | No trophy; log it |

**Whole-request failures** (`Ok = false`, no mutation, empty `Results`):

| Error | Cause |
|---|---|
| `Disabled` | The feature flag is off. |
| `Malformed` | The request is not a table. |
| `UnknownEvent` | The event id is not a known completion context. |
| `LandmarkMismatch` | The landmark does not match the event. |
| `BadInstanceId` | The instance id is missing or invalid. |
| `NotCompleted` | The outcome is not `Completed`. |
| `BadRewardVersion` | The reward version is invalid. |
| `BadParticipants` | The list is empty or over 16 entries, has duplicate UserIds, or has non-finite or wrongly typed fields. |

These are programming errors on the caller's side. Log them; don't retry blindly.

**Other server API.**

| Function | Returns |
|---|---|
| `Owns(player, trophyId)` | `boolean?`, where `nil` means not loaded (unknown, not false) |
| `GetTrophies(player)` | A copy of the player's trophies |
| `GetCampLayout(player)` | A copy of the camp layout |
| `GetTrophySlots(player)` | Number of trophy slots |
| `HasPendingGrant(userId)` | Whether an offline grant is waiting |
| `SetEnabled(bool)` | Feature flag `Trophies` |
| `TrophyGranted` / `CampChanged` | Signals for UI, analytics or quest hooks such as q_trophies |

`SetEnabled(false)` blocks new grants and camp edits only. Earned trophies stay owned and
queries keep working.

Clients cannot grant trophies:

- No remote grants. The camp remotes accept only `(trophyId, x, z, rot)` and `(placementId)`.
- They are rate-limited at 4 per second and act only on trophies the player already owns.
- No asset ids, studs or CFrames are accepted.

## Camp display

- **Grid and footprint.** Placements snap to a 2-stud grid (cells 0..11) on a 24×24 pad,
  with rotation 0/90/180/270. The stand's 2×2 footprint is one cell.
- **Placement limits.** One display per owned trophy, 3 trophy slots and 32 placements in
  total. Out-of-bounds, fractional, NaN or infinite cells are rejected server-side.
- **Removal keeps ownership.** `RemovePlacement` edits only `CampLayout`, so the trophy
  stays owned, and placement ids are never reused.
- **What gets built.** Each placement is a `TrophyStand` pivoted to the cell, with a
  `TrophyReplica` on its `TrophySlot`.
  - Every part is anchored and non-colliding; replica parts are also non-query and
    non-touch. So a display can't block paths or digging.
  - The camp model carries `OwnerUserId`, `OwnerName` and `PadIndex` attributes.
- **Pads.** Pads are borrowed, not saved. A loaded player with a non-empty layout gets the
  lowest free pad. Leaving unloads the camp and frees the pad, and rejoining rebuilds it.
  If no pad is free, the layout still saves; nothing is shown.

## Shared-file wiring (apply after review)

`docs/trophy-integration.patch` has 8 added lines in 2 files. `git apply --check` passes
against `afbb8a0`.

1. `src/shared/Remotes.luau`: add `"PlaceCampItem"` and `"RemoveCampItem"` to
   `Remotes.Events`. `Remotes.Get` asserts on unknown names, so this branch cannot create
   them itself.
2. `src/server/Main.server.luau`:
   - Require `Services.TrophyService`.
   - Add it to `ordered` after `OfflineService`. It depends only on DataService.
   - Call `run("TrophyService", "ConnectRemotes", TrophyService.ConnectRemotes, Net)` after
     the `Init` loop.
3. `tests/run.sh`: add `luau tests/trophy-wired.spec.luau || status=1`.

Not in the patch, and owned elsewhere:

- **Map/World.** Place 16 `TrophyCampPad`-tagged anchored parts. The 24×24 area is centred
  on the part's top surface, clear of transit and NPC pads. Alternatively, call
  `TrophyService.SetCampPads({CFrame})`. With no pads, nothing renders.
- **Config.** An optional `Trophies` flag that calls `SetEnabled`.
- **Types.** Optional typed fields on `Types.PlayerData` (`TrophyRecords`, `CampLayout`,
  `RewardReceipts`, all optional `?`).
- **Client UI.** A camp edit UI and trophy collection view. Today the client can read the
  replicated keys, but there is no UI.

## Open decisions for review (not invented here)

1. **Trophy stand entitlement.** The catalog lists `camp_trophy_stand` as a q_mara cosmetic
   reward. This branch treats the stand as part of every trophy display, following the
   asset handoff's "trophy display" stand + replica, and does not require stand ownership.
   If the owner wants the stand gated, the quest owner needs to grant that cosmetic, and
   `ValidatePlacement` needs one more check.
2. **The `RewardReceipts` table is shared with future reward code.** This branch writes
   only `trophy:`-prefixed keys with unix-number values, and prunes only those. If Codex
   adds stage/coin receipts, use another prefix in the same table, or a separate field.
   Never rewrite the `trophy:` keys.
3. **Cross-server and shutdown exactly-once.** Online grants persist in the player's save.
   `PendingRejoin` is in-memory: it survives a reconnect to the same server but not a
   server shutdown or a rejoin on another server. Bible ch.04 says an in-memory set is not
   sufficient for exactly-once. Closing that gap needs a persisted intent queue that writes
   to an offline player's session-locked record, which is a DataService-level change.
   Until then, settle while players are present, and hold disconnected slots for 90 s as
   the bible specifies. Note that Codex's runtime currently marks a player who is
   disconnected at completion `Eligible = false`, so through `OnCompletion` they get
   nothing rather than `PendingRejoin`. Whether a disconnected contributor should still
   earn the trophy is a design call for the owner and Codex. If yes, the runtime should
   leave `Eligible` true for them, and the pending path will handle it.
4. **Other trophy work is out of scope.** This branch does not do the following, which need
   EconomyService/DiscoveryService changes:
   - Treasure trophies: first-find records, records created at sale, legacy Index replicas.
   - Camp furniture, banners, preview mode and tier-2 slots.
   - The coin/cert_crew grants for event_vault, which belong to the adventure/quest owner.

## Verification: what is and isn't proven

**Headless mock tests**, run on Windows with the repo's luau 0.640 toolchain. The
in-memory DataStore is driven through the real DataService code.

- `trophy.spec`: 227 checks.
  - Migration of a representative v3 save, idempotence, and repair of malformed/hostile
    fields.
  - Receipt bounds and the eligibility rule.
  - Solo, crew, late-helper and spectator outcomes.
  - Repeat, retry, second-instance and reward-version duplicates.
  - Rejected inputs changing nothing, and the feature flag.
  - Leave/rejoin persistence, plus an offline-eligible player getting the grant on rejoin.
  - Placement bounds/rotation/ownership/duplicates and display geometry and collision flags.
  - Pad allocation and release, removal without ownership loss across save/rejoin, and
    rebirth keys.
  - A store outage at settlement followed by a successful leave save.
  - The adventure CompletionContext mapping and its Eligible veto.
- **Mutation check.** Disabling the points threshold, the ownership guard, the receipt
  guard, the bounds check, the immediate save, or ownership preservation in migration each
  fails the spec.
- **Wired check.** With the patch applied in a scratch copy, `trophy-wired.spec` (17), the
  smoke tests (live and Studio-mode), `client.spec` and `trophy.spec` all passed. That run
  covers booting Main with the service wired, the remotes driven as a client, a real
  rebirth, and leave/rejoin.
- **Full suite on this branch** (no patch): util 8, trophy 227, smoke 2,199, Studio-mode
  smoke 2,166, persistence boot (both modes) and client 1,464 all passed. StyLua is clean
  on the new files. The strict luau-lsp check shows only the two existing
  deprecated-API warnings. The Rojo build succeeds.

**Not verified:**

- Live Roblox DataStore persistence, cross-server rejoin, a real shutdown mid-settlement,
  real multiplayer and the display in Studio lighting were not tested.
- Studio API access was deliberately not enabled, because it would write to the live
  experience's save store.
- Live persistence remains unproven until a private test place runs the save/leave/rejoin
  on another server (see `docs/TEST_EXPERIENCE_PROPOSAL.md`).

Run locally (Windows, with the toolchain in the main checkout's `.tools/`):
`ROBLOX_DEFS=.tools/globalTypes.d.luau python -X utf8 tests/tools/bundle.py`, then
`.tools/luau.exe tests/trophy.spec.luau`.
