# Adventure trophies: integration handoff

Branch `claude/adventure-trophies`, prepared 9 October 2026 and revised the same day after the
owner's boundary decisions. Scope: permanent adventure trophies and their camp display (game
bible milestone 2 trophy slice, applied to the Spring Vault).

This branch does not implement the Spring Vault adventure, NPCs, Broadwave, anchors, vault
opening, ball routing or effects, which belong to Codex's branch. It does not edit shared boot
files, DataService, Config, Types or Codex's files. The one shared-file change is a single line
in `tests/run.sh` that registers the new spec. Nothing was uploaded or published.

## Owner decisions (9 October 2026)

| Decision | How this branch applies it |
|---|---|
| Production display requires Mara's trophy stand. The first eligible completion grants the stand and trophy together. A review preview can bypass the check. | One save mutation writes `TrophyRecords.landmark_spring_vault` and `Cosmetics.camp_trophy_stand` under the same receipt. Placement is refused with `NoStand` and the camp is hidden without the stand. `SetReviewPreview(true)` bypasses the check in Studio only; a live server refuses it. |
| Receipt ownership stays separate. | Trophy code writes and prunes only `trophy:`-prefixed `RewardReceipts` keys. Reward code owns its own prefix. |
| Disconnected players stay ineligible for the final trophy. Accepted pending grants need durable storage. Same-server-only recovery is a release blocker. | The runtime's `Eligible` veto is honoured, so disconnected players get nothing. Any accepted grant for a player not loaded here goes to a durable DataStore outbox before `PendingRejoin` is reported, and is applied on their next load on any server. The in-memory pending list is gone. |
| Treasure and legacy trophies, furniture, camp UI and the 16 camp pads are outside this slice. Camp display wiring is a production gate. | Not implemented. See "Production gates". |

## What is in this branch

| File | Role |
|---|---|
| `src/shared/Trophies/Catalog.luau` | Trophy definitions. Only `landmark_spring_vault`, with source `event_vault`, region `sunshine_shore` and replica `TrophyReplica`. There is no payout or sale field. |
| `src/shared/Trophies/Rules.luau` | Pure rules: save migration/repair, receipts and pruning, the eligibility rule, outbox entry validation, and camp grid and stand validation. |
| `src/server/Services/TrophyData.luau` | The narrow adapter to the existing `DataService`. It is the only trophy file that touches the player save. |
| `src/server/Services/TrophyPendingStore.luau` | The durable outbox for accepted grants to players who are not loaded here. It holds intents only, never progress. |
| `src/server/Services/TrophyService.luau` | Server-authoritative settlement API, ownership queries, camp place/remove, review preview and remote handlers. |
| `src/server/Services/TrophyCampDisplay.luau` | Builds camps from `Models.Expansion1.TrophyStand()` + `TrophyReplica()` on reserved pads. |
| `tests/trophy.spec.luau` | 312 headless checks (314 once the patch adds the two camp remotes), including a second mock server and the authored camp pad. Registered in `tests/run.sh`. |
| `src/server/World/CampPad.luau` | Builds the one authored camp pad (`Layout.CAMP_PADS`) in `Map.Hub`. |
| `tests/trophy-wired.spec.luau` | 18 checks through the real `Main` with the patch applied. Register it when the patch merges. |
| `docs/trophy-integration.patch` | The exact shared-file wiring, tested (see below). |

## Persistence

### Player save: the existing DataService record

Trophy state is four top-level `PlayerData` keys in the same session-locked `DataService`
record (`PlayerData_v1`, key `Player_<UserId>`). They use the names from bible ch.04:

```
TrophyRecords  = { [trophyId] = { Kind, Source, RegionId, AcquiredAt, ReceiptId, Legacy, ContentVersion } }
CampLayout     = { Placements = { { Id, TrophyId, X, Z, Rot } }, NextId }
RewardReceipts = { ["trophy:<InstanceId>:<UserId>:final:v<RewardVersion>"] = settledUnix }  -- trophy: prefix only
Cosmetics      = { camp_trophy_stand = { Kind, Source, AcquiredAt, ReceiptId } }           -- this key only
```

`Cosmetics` is the bible's shared cosmetic inventory. Trophy code creates the table if it is
missing and writes only `camp_trophy_stand`. Other cosmetic keys are never read or changed.

This works without editing DataService. These facts were checked in source and by tests:

- `DataService.sanitize` → `TableUtil.Reconcile` keeps keys the template does not know.
  `saveAsync` writes a deep copy of the whole save. That means the currently published v17
  server also carries these keys through untouched, which makes rollback compatible.
- Saves use the normal autosave, leave and `BindToClose` paths. A settlement also calls
  `DataService.SaveAsync` immediately, because DataService serializes saves.
- The keys replicate to the owner through the existing `DataChanged` deltas.
- Rebirth resets only `Config.Rebirths.Resets`, which does not include these keys. The
  wired spec runs a real rebirth and checks this.

**Migration.** `TrophyData.Get` runs `Rules.Migrate` once for each loaded save table.

- It adds the four keys to any existing save and repairs malformed values.
- It changes no other key. The tests compare every other field before and after.
- It is idempotent.
- It never deletes an owned trophy id or the stand. A non-table value is kept as
  `{ Repaired = true }`. Records unknown to this server are kept as-is.
- It invents nothing. Legacy saves get no trophy and no stand.
- Invalid camp placements are dropped. That loses a display only, never ownership.

`Config.DATA_VERSION` stays at 3. When the whole DataVersion 4 field set lands, an optional
hook is to add `[3] = function(d) Rules.Migrate(d, os.time()) end` to DataService's
`MIGRATIONS`. That is safe because the function is idempotent.

### Durable pending grants: the outbox

The outbox lives in DataStore `TrophyPendingGrants_v1`, key `Pending_<UserId>`, with value
`{ Grants = { [receiptId] = { TrophyId, Source, RegionId, At } } }`. It holds up to 8 intents
per user. It stores no player progress.

1. **Settlement.** When an accepted grant is for an eligible player whose save is not
   loaded on this server, settlement writes the intent with `UpdateAsync`, keyed by receipt
   id, so a retry is a no-op. It reports `PendingRejoin` only after the write succeeds.
   Otherwise it reports `Refused / PendingWriteFailed` and the caller can retry the same call.
2. **Next load, on any server.** `TrophyService` reads the intents, re-validates them, and
   applies them to the live save. Receipt and ownership checks make re-application a
   `Duplicate`. It then saves through `DataService.SaveAsync`.
3. **Acknowledge.** Applied receipts are removed from the outbox only after that save
   succeeds. If the server crashes after the save but before the acknowledgement, the next
   load re-applies the grant as a `Duplicate` and acknowledges it then. Unreadable entries
   are dropped at acknowledgement, so they can't hold the bound.

Store availability follows DataService:

- **Studio without API access.** Uses an in-memory outbox, mirroring DataService's fallback.
- **Live server with the outbox store unavailable.** Refuses pending grants rather than
  claiming they are durable.

With Codex's runtime, eligible players are always connected and loaded at completion. That
means this path only runs in edge cases, such as a save that failed to load, or callers of
the general API.

### Bounds

| Item | Bound |
|---|---|
| Trophy records | 256. New grants beyond that are refused with `Refused/RecordLimit`. Loads never delete records. |
| Layout | 32 placements. |
| Starting trophy slots | 3. |
| Receipts in the `trophy:` namespace | 512 most recent, kept for at most 30 days. |
| Outbox | 8 intents per user. A 9th is refused with `Refused/PendingFull`. |

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
`true`. That flag also requires the player to be connected and present at completion, so
disconnected players are never granted the final trophy, as the owner decided. A vetoed
player reports `Ineligible / EventIneligible`.

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
contributions, and before cleanup returns or removes players. It is server-only.

**Yielding.** Loaded players are settled synchronously first. The call yields only while
writing outbox intents for eligible players who are not loaded here. Codex calls
`OnCompletion` from a Heartbeat connection after setting `completionSent`, so a yield there
cannot double-submit. It is safe to call again with the same arguments, for example on a
retry.

**InstanceId.** Use something unique across servers and runs, such as
`(game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)) .. ":" .. sequence`
with a per-server sequence number. Codex's runtime already uses a session GUID plus a
sequence.

**Eligibility.** The service applies bible ch.04's rule itself:

- Solo: if `#Participants == 1` and `ObjectiveCompletions >= 1`, the player is eligible.
- Otherwise the player needs `Points >= 5` and, in addition, either `PresentForObjective`
  or `ActiveSeconds >= 30`.
- Presence alone never qualifies.
- The participant list must include ineligible spectators, because the solo rule is based on
  the list size.

**Return value.** `SettlementReport`:

```lua
{
	Ok = boolean,
	Error = string?,        -- only when Ok == false; then NOTHING changed for anyone
	EventId, LandmarkId, InstanceId,
	Results = { { UserId, Status, Reason?, StandGranted? } },  -- same order as Participants
	ByUserId = { [UserId] = result },
}
```

| Status | Meaning | What to show |
|---|---|---|
| `Granted` | The trophy is newly owned. The stand was added too if missing (`StandGranted = true`). The record, stand and receipt were written in one synchronous save mutation, and a save was requested. | Trophy reward |
| `AlreadyOwned` | The trophy was owned from an earlier run. Nothing changed, except that a missing stand is added (`StandGranted = true`). | Completion only |
| `Duplicate` | This exact receipt was already settled, so this is a retry. Nothing changed. | Same as the first response |
| `PendingRejoin` | Eligible and not loaded here. The intent is durably stored and applied on the player's next load on any server. | Nothing to that player now |
| `Ineligible` | `Reason` is `LowContribution`, `NotPresent` or `EventIneligible`. | No trophy |
| `Refused` | `Reason` is `RecordLimit`, `PendingFull`, `PendingWriteFailed` or `NotLoaded`. Not stored. | No trophy. Log it; `PendingWriteFailed` can be retried. |

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
| `OwnsStand(player)` | `boolean?`, same convention |
| `GetTrophies(player)` | A copy of the player's trophies |
| `GetCampLayout(player)` | A copy of the camp layout |
| `GetTrophySlots(player)` | Number of trophy slots |
| `GetPendingGrants(userId)` | Reads the outbox; yields |
| `SetEnabled(bool)` | Feature flag `Trophies` |
| `SetReviewPreview(bool)` | Studio only; returns whether preview is on |
| `TrophyGranted` / `CampChanged` | Signals for UI, analytics or quest hooks such as q_trophies |

`SetEnabled(false)` blocks new grants and camp edits only. Earned trophies stay owned and
queries keep working.

Clients cannot grant trophies:

- No remote grants a trophy or the stand. The camp remotes accept only
  `(trophyId, x, z, rot)` and `(placementId)`.
- They are rate-limited at 4 per second and act only on trophies the player already owns,
  and only with the stand.
- No asset ids, studs or CFrames are accepted.

## Camp display

- **Stand required.** Production display requires owning `camp_trophy_stand`. Without it:
  - Placement is refused with `NoStand`, and the player sees "You need Mara's trophy stand
    first."
  - The camp is hidden. The saved layout is kept, and it appears once the stand is owned.
  - `SetReviewPreview(true)` bypasses the check, in Studio only. It grants nothing, and
    turning it off hides the camp again.
- **Grid and footprint.** Placements snap to a 2-stud grid (cells 0..11) on a 24×24 pad,
  with rotation 0/90/180/270. The stand's 2×2 footprint is one cell.
- **Placement limits.** One display per owned trophy, 3 trophy slots and 32 placements in
  total. Out-of-bounds, fractional, NaN or infinite cells are rejected server-side.
- **Removal keeps ownership.** `RemovePlacement` edits only `CampLayout`. The trophy and
  stand stay owned, and placement ids are never reused.
- **What gets built.** Each placement is a `TrophyStand` pivoted to the cell, with a
  `TrophyReplica` on its `TrophySlot`.
  - Every part is anchored and non-colliding; replica parts are also non-query and
    non-touch.
  - The camp model carries `OwnerUserId`, `OwnerName` and `PadIndex` attributes.
- **Pads.** Pads are borrowed, not saved. A loaded player with a non-empty layout gets the
  lowest free pad. Leaving unloads the camp and frees the pad. If no pad is free, the layout
  still saves; nothing is shown.
- **The authored pad (claude/trophy-camp-pad).** The world builds exactly one pad,
  `Workspace.Map.Hub.TrophyCampPad1` (`World/CampPad.luau`, coordinates in
  `Layout.CAMP_PADS`):
  - Centre (80, 1024, 76), on open sand between the Rebirth shrine and the Beach Shop. The
    deck is 24×1×24 wood planks, top at `Layout.DECK_TOP` (1027). The `Deck` part is anchored,
    walkable and tagged `TrophyCampPad`. A non-colliding rim, gold corner posts and a
    "TROPHY CAMP" sign stand just outside the footprint; the sign faces the plaza and names the
    owner.
  - Clearance: every other map part is at least 10 studs away. The smoke spec checks that no
    map part enters the footprint plus 2 studs. The pad is more than 60 studs from the spawns,
    off the deck-to-plaza path, and 70 studs inland of the dig zone.
- **Dig protection.** The dig zone clamp already keeps every carve out of the hub.
  `World.IsProtected(position, margin)` also covers the pad footprint plus rim in X/Z at any
  depth. `DigService.DigAt` refuses (`OutOfZone`) any dig whose carve could reach it (margin =
  dig radius + one voxel), so the pad stays safe if the pad or the zone ever move. The Studio
  `/dig` dev command is clamped to the zone.
- **Ownership rules** (`TrophyService` camp section):
  - A pad shows exactly one owner's camp. A player claims a free pad only when they are
    loaded, own the stand (or the Studio review preview is on) and have a non-empty layout. A
    player without the stand never claims one.
  - Place and remove act only on the caller's own `CampLayout`; placement ids are per player.
    Nothing another player sends can change someone else's camp, and `Display.Show` never
    takes a pad someone else holds.
  - When the pad is busy, an eligible player's placement still saves. They join a FIFO wait
    list and nothing is shown for them.
  - **Automatic hand-over.** When the pad is released (the owner leaves, empties their camp,
    or loses display rights), it goes at once to the longest-waiting player who is still
    loaded and eligible. A rejoining former owner waits like anyone else; the pad is never
    taken back from its current owner.
  - Read-only queries: `TrophyService.GetCampPadOwner(padIndex)` returns the owner's UserId or
    nil. `GetCampPad(player)` and `GetCampPadCount()` are also available. The pad's `Deck`
    carries the attributes `OwnerUserId` (0 when free), `OwnerName` and `PadIndex`. The server
    writes them and they replicate to clients; client writes never replicate back.
  - `SetCampPads` is a boot-time override and does not move camps that are already shown.

## Shared-file wiring (apply after review)

`docs/trophy-integration.patch` has 8 added lines in 2 files. `git apply --check` passes
against `afbb8a0`.

1. `src/shared/Remotes.luau`: add `"PlaceCampItem"` and `"RemoveCampItem"` to
   `Remotes.Events`. `Remotes.Get` asserts on unknown names, so this branch cannot create
   them itself.
2. `src/server/Main.server.luau`:
   - Require `Services.TrophyService`.
   - Add it to `ordered` after `OfflineService`. It depends only on DataService, whose
     `Init` must run first; the existing order guarantees that.
   - Call `run("TrophyService", "ConnectRemotes", TrophyService.ConnectRemotes, Net)` after
     the `Init` loop.
3. `tests/run.sh`: add `luau tests/trophy-wired.spec.luau || status=1`.

## Production gates (owner-listed, outside this slice)

- **Camp display wiring.**
  - Map/World: one authored pad now exists (see "Camp display"). The full 16 pads are still
    open: add more centres to `Layout.CAMP_PADS`, clear of transit and NPC pads; the display
    and the ownership rules already handle N pads.
  - A client camp edit UI and trophy collection view. Today the client can read the
    replicated keys, but there is no UI.
- **Treasure and legacy trophies** (first-find and sale records, legacy Index replicas) and
  camp furniture, banners and tier-2 slots.
- **Optional shared changes.** A Config `Trophies` flag calling `SetEnabled`, and optional
  typed fields on `Types.PlayerData`.
- **Live persistence evidence.** Grant, leave, and rejoin on a different server, plus an
  outbox recovery, on a private test place. See "Verification".

## Release blocker status

**Same-server-only recovery.** The code now addresses it: accepted pending grants are
durable and are applied on any server, with exactly-once handling across a crash between
save and acknowledgement. The evidence is mock only, including a second mock server sharing
the store. The blocker should stay open until a private test place confirms the outbox and
cross-server application against real DataStores.

## Verification: what is and isn't proven

**Headless mock tests**, run on Windows with the repo's luau 0.640 toolchain. The
in-memory DataStore is driven through the real DataService code.

- `trophy.spec`: 259 checks (261 with the patch applied). Beyond the original coverage (migration, eligibility,
  duplicates, rejected inputs, flag, placement bounds and geometry, pads, removal across
  save/rejoin, rebirth keys, store outage, runtime-context mapping), it adds:
  - The stand granted with the first trophy, sharing its receipt.
  - A missing stand added on the next completion.
  - A camp hidden and placement refused without the stand.
  - The review preview refused on a live server, working in Studio, and granting nothing.
  - An outbox write before `PendingRejoin`, and write failure reported as
    `PendingWriteFailed`, then a successful retry.
  - The outbox bound.
  - Acknowledgement only after the save.
  - A crash between save and acknowledgement re-applying as a `Duplicate`, with a corrupt
    entry dropped.
  - A grant queued on server A and applied, saved and acknowledged on a fresh second mock
    server.
- **Mutation check.**
  - Original guards: disabling the points threshold, ownership guard, receipt guard, bounds
    check, immediate save, or migration ownership preservation each fails the spec.
  - New guards: removing the stand placement check, the stand grant, the display gate, or
    reporting pending without a successful write each fails it too.
- **Wired check.** With the patch applied, `trophy-wired.spec` (18), `trophy.spec`, the smoke
  test and `client.spec` all pass. That run covers booting Main with the service wired, the
  remotes driven as a client, a real rebirth, and leave/rejoin.
- **Full suite on this branch** (no patch): util 8, trophy 259, smoke 2,199, Studio-mode
  smoke 2,166, persistence boot (both modes) and client 1,464 all pass.
  - StyLua is clean on the new files.
  - The strict luau-lsp check shows only the two existing deprecated-API warnings.
  - The Rojo build succeeds.

**Not verified:**

- Live Roblox DataStore persistence, real cross-server rejoin, the real outbox store, a real
  shutdown mid-settlement, real multiplayer and the display in Studio lighting were not
  tested.
- Studio API access was deliberately not enabled, because it would write to the live
  experience's save store.

Run locally (Windows, with the toolchain in the main checkout's `.tools/`):
`ROBLOX_DEFS=.tools/globalTypes.d.luau python -X utf8 tests/tools/bundle.py`, then
`.tools/luau.exe tests/trophy.spec.luau`.
