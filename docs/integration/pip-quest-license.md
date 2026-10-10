# q_pip: the permanent Broadwave license, and rides kept out of the pocket

Branch `claude/svc-pipquest`, 10 October 2026, based on default `d96ac75`. Nothing is pushed,
uploaded or published. Every `AdventureFlags` flag still ships **off**. Codex's runtime
(`src/server/Adventure`, `src/client/Adventure`) is not edited.

## 1. What grants the license

On owner instruction, **completing Pip's Broadwave trial grants the permanent license**, once:

```lua
data.ToolLicenses.tool_broadwave = { Source = "q_pip", ReceiptId = "quest:q_pip", At = os.time() }
```

The game bible puts the permanent license at `cert_explorer` (catalog rows `tool_broadwave` and
`q_pip`). The owner's instruction replaces that. The bible's **150-coin first-clear q_pip
reward is not implemented** (owner decision). No coins, shovels, quests or certifications are
touched.

New module: `src/server/Services/PipQuest.luau` (Claude-owned).

| Piece | Behaviour |
|---|---|
| `Rules.Grant(data, now)` | Pure. Writes the record and returns `(true, "Granted")`. An existing record returns `(false, "Duplicate")` and is left untouched. No data returns `(false, "NotLoaded")`. Creates `ToolLicenses` if missing; other licenses are kept. |
| `Rules.TrialComplete(trial)` | `Wave == true`, `Cleared >= 3`, and `trial_target_1`, `_2`, `_3` all `true`. |
| `Check(player)` | Reads only server state (below), then grants. |
| `Start(runtime)` / `Stop()` | Started by `AdventureBoot` and stopped by `AdventureBoot.Disable`. |

`Check(player)` grants only when all of these hold:

- PipQuest is running and ordinary Broadwave is still enabled;
- the player is in the game and `DataService.IsLoaded`;
- the save has no license yet (otherwise `Duplicate`);
- `runtime.ReviewPlayer(player).Trial` is complete (`Rules.TrialComplete`). This is the
  runtime's frozen copy of its own trial table;
- `AdventureEligibility.CanTrial(player)`: the player still owns a bought shovel.

On a grant it runs `DataService.Mutate(player, {"ToolLicenses"}, ...)`, a spawned
`DataService.SaveAsync`, and `BroadwaveLicense.Sync(player)`, so the licensed tool is in the
Backpack at once. It then sends a `Success` toast:
"Pip: Broadwave license earned! It is yours to dig with on the beach."

### When the check runs

The runtime has no completion callback, and it is Codex's code, so PipQuest watches it from
outside:

- **Intent.** PipQuest connects to `ReplicatedStorage.SpringVaultAdventure.Intent.OnServerEvent`
  after the runtime starts. Its handler is connected after the runtime's, so it runs second.
  It never reads the payload. It only schedules a deferred `Check(player)`.
- **Poll.** Once a second, `Check` runs for every present player who has an active trial. This
  catches trials finished through `runtime.Handle`, which fires no remote.

A spoofed payload therefore does nothing on its own. Without the server's trial state there is
no grant.

### Flags

| `BroadwaveOrdinary` | Result |
|---|---|
| on, with the bridge present | PipQuest starts after `SpringVaultService.Start` succeeds. |
| off (or bridge missing) | PipQuest is never started. Pip's trial stays a demo: the loan works at the trial patch and nothing is granted. |

`AdventureBoot.Disable` stops PipQuest before anything else. A license already granted stays in
the save.

### Loans still never count

The trial loan never gives ordinary digging rights, before or after the grant.
`CanUseBroadwave` accepts only a tool this server issued through `BroadwaveLicense`, so the loan
is refused. `ResolveTool` never returns it, and on ordinary sand it neither charges nor digs. The
licensed tool is accepted and digs. `pip-quest.spec` checks every one of these.

### Reachability

Pip is inside the pocket, and the hatch admits only `CanEnter` players. A player with a bought
shovel but no Rookie certificate or catch-up evidence cannot reach Pip yet. This is open owner
decision 16 in `README.md`.

## 2. Rides cannot bypass the pocket

`RideService.spawnRide` only checks horizontal distance to the ride area
(`Config.Ride.SpawnMaxDistance = 40`). It ignores height. Measured in `pip-quest.spec`:

| Point | Horizontal distance to the ride area |
|---|---|
| Pocket arrival point (`AdventureEntry.ArrivalFrame`) | 126.0 studs |
| Nearest point in the runtime's presence box, at (-248, 2) | **0.0 studs** |
| Nearest `InPocket` point | 0.0 studs |

The ride area is X[-377, 377], Z[-57, 4]. The arena's far edge (world Z ≈ 1) lies under it. Every
arena point with Z ≤ ~44 passes the old check. Without a guard, ToggleRide there **did spawn a
ride** (spec control case) and seated the player in a vehicle on the beach. That is a free exit
from the pocket.

The fix:

- `RideService.SetSpawnGuard(fn: ((Player) -> string?)?)` adds one server veto, checked before
  every spawn. It returns refusal text (shown as an `Error` toast) or nil. A guard that errors
  refuses. `RideService` never requires its installer, so there is no require cycle.
- `AdventureEntry.Start` installs a guard. It refuses when the player's root is `InPocket`, with
  "Rides stay on the beach." `AdventureEntry.Stop` clears it.
- `AdventureEntry` despawns any ride when it moves a player into the pocket. Its 0.2 s check also
  despawns the ride of anyone found in the pocket while riding.
- Unchanged: the hatch still refuses seated players ("Hop off your ride first.").

## 3. Tests

`tests/pip-quest.spec.luau` boots the real Main. It is registered in `tests/run.sh`.

| Run | Checks |
|---|---|
| `luau tests/pip-quest.spec.luau` (SpringVault + BroadwaveOrdinary on) | 75 |
| `luau tests/pip-quest.spec.luau -a off` (BroadwaveOrdinary off) | 25 |

What the spec covers:

- `Rules.Grant`: idempotent; record shape; nothing else written.
- No bought shovel: no trial and no grant.
- Spoofed Intent payloads with no server trial state: no grant (`Incomplete`).
- A partial trial (wave plus 2 targets): no grant.
- A full trial through the Intent remote:
  - the grant is deferred, then made once;
  - only the `ToolLicenses` key is mutated;
  - shovels, coins, quests and certifications are unchanged;
  - one toast;
  - the licensed tool is issued immediately.
- After the grant:
  - the loan is still refused and the licensed tool accepted;
  - end to end, the loan does not dig and the licensed tool digs.
- Repeat completions:
  - the poll over a complete trial and a second full completion both leave the receipt
    unchanged;
  - no second toast;
  - still exactly one licensed tool.
- Poll path through `runtime.Handle`, with no remote:
  - `CanTrial` is checked again at grant time (shovel removed: `NoShovelPurchase`);
  - the grant comes once the player is eligible again.
- Rides:
  - the measured distances above;
  - the guard is installed;
  - ToggleRide is refused from the pocket, with a toast;
  - a control run without the guard spawns a ride, which is then despawned;
  - the ride works on the beach;
  - the hatch refuses a seated player;
  - a rider moved into the pocket loses the ride.
- Kill switch:
  - a completion right before `Disable` never grants;
  - `Check` returns `NotRunning`;
  - a granted license is kept;
  - the ride guard is cleared.
- Off mode:
  - PipQuest is not started;
  - the full trial still runs as a demo and grants nothing.

MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no Studio or real clients.

## 4. Follow-ups

- **Codex (copy):** on trial completion the runtime still says "Pip: Excellent! Broadwave trial
  complete. No permanent license or trial coins awarded in review." In production with
  `BroadwaveOrdinary` on, PipQuest's grant toast follows it. The runtime line should drop the
  "No permanent license" clause, or yield to an external owner as `OutcomeOwner` does.
- **Codex (optional):** a completion callback option (for example `OnTrialComplete(player)`) would
  replace the Intent listener and the poll. PipQuest keeps the same server-state check either
  way.
- **Owner:** the 150-coin first-clear reward (not implemented), and decision 16 (hatch admission
  for players who only qualify for the trial).
