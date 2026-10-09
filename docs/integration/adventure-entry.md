# Adventure entry, return and pocket lighting

Branch `claude/svi-entry`, based on `claude/spring-vault-production-integration` `3e216f5`
(consolidated adventure patch applied, every flag off). 9 October 2026. Nothing is pushed,
uploaded or published, and no flag in `AdventureFlags` is turned on.

This closes two blockers from `README.md` ("Blocking before any flag is turned on"):

- **1.** The review arena's neutral `SpawnLocation` must not exist in production (review H1).
- **4.** Players need a way into the under-slab arena and back, plus lighting there.

Codex's runtime files (`src/server/Adventure/*`, `src/client/Adventure/*`, `src/shared/Adventure/*`,
the Expansion1 factories) are untouched. The changes this work needs from them are listed under
"Requests to Codex".

## Files

| File | Change |
|---|---|
| `src/server/Services/AdventureEntry.luau` | New. Surface entrance, return pad, return rules, pocket lighting rig |
| `src/server/Services/AdventureBoot.luau` | Spawn guard now removes the spawn; starts and stops `AdventureEntry` |
| `tests/adventure-entry.spec.luau` | New. Scenarios `off` and `on` |
| `tests/production-wiring.spec.luau` | Spawn check now expects the spawn to be gone; checks the entry folder in off, on and after the kill switch |
| `tests/run.sh` | Registers both `adventure-entry` scenarios |

### `AdventureBoot.luau` edits

The edits are kept small because another agent is editing `AdventureBoot.Options`. `Options`
is unchanged.

1. `local AdventureEntry = require(script.Parent.AdventureEntry)` is added after the
   `AdventureSettlement` require. Requiring it builds nothing.
2. `disableSpawns` and the inline `DescendantAdded` handler are replaced by `removeSpawn(d)`. It
   sets `Enabled = false`, `Neutral = false` and `AllowTeamChangeOnTouch = false` immediately,
   then calls `task.defer(d:Destroy)`. `guardScene()` runs it on the scene's existing descendants
   and on `DescendantAdded`. The destroy is deferred because the scene parents its model
   *before* it creates the spawn, so the spawn shows up through `DescendantAdded` while it is
   being parented, and destroying it there would re-parent it in the middle of that parent
   change. Until the deferred destroy runs, the spawn is disabled and not neutral, so no player
   can spawn on it.
3. In `Start`, right after `runtime = result`: `AdventureEntry.Start(result, AdventureBoot.POCKET_ORIGIN)`.
4. In `Disable`, after the `if runtime then ... pcall(r.Destroy) ... end` block:
   `AdventureEntry.Stop()`. It always runs and does nothing if the entry was never started.
5. The header comment and the `Disable` comment are updated to match.

Nothing in the runtime refers to `AdventureReviewSpawn`. It is a local variable inside
`Scene.Build` and is never returned or read, so destroying it is safe. The spawn sat on top of
the floor, so no hole is left.

## What is built (only with `SpringVault` on)

Everything is under `Workspace.AdventureEntry`, which `Stop()` destroys.

### Surface entrance: `Entrance`

- **Where:** centre `(-124, 1024, 76)` (`AdventureEntry.ENTRANCE`).
- **Parts:** a 10x1x10 wooden deck (collidable, top at `DECK_TOP` 1027) and a 6x0.4x6 navy
  hatch (non-colliding). A "SPRING VAULT" sign ("Adventure below the sand") on a post at the
  east edge faces the plaza.
- **Prompt:** server ProximityPrompt `AdventureEntryPrompt` on the hatch, "Go down" /
  "Spring Vault", 0.5 s hold, 10-stud range.
- **Protection:** every part is tagged and has the `ProtectedGeometry` attribute.

**Why there:**

- It is open sand west of the crate yard fence (x ≈ -101) and north-east of the Sandcastle
  Contest (-150, 40).
- A scan of the built map found no map part within 14 studs. The spec checks that no map part
  comes within 4 studs of the pad.
- It is about 140 studs from the dig zone. `World.IsInDigZone` is false at every corner.
- It is about 200 studs from the camp pad. `World.IsProtected(corner, 8)` is false at every
  corner, and `IsProtected(centre, 12)` is false.
- It is more than 60 studs from every boardwalk spawn, and it is off the plaza paths and
  station fronts.
- It is reachable from the plaza in a few seconds by walking west past the crate yard. Its X is
  about 26 studs east of the pocket's X range, which keeps streaming distances short (about
  115 studs between the hatch and the arrival point; `StreamingTargetRadius` is 320).

`EntranceIsSafe()` checks the dig zone and the camp pad again at start, and refuses to build
the entrance if either check fails.

### Arrival

- **Where:** `origin + (-10, 3.5, 24)`, which is (-210, 973.5, 130) in world coordinates,
  facing -Z (towards the vault).
- **Clearances:** it is inside the runtime's presence box. It is about 13.8 studs from Mara,
  so her prompt is a few steps away and not on top of the player. It is at least 5 studs (XZ)
  from every scene target, and about 10.8 studs from the old spawn spot.

### Pocket: `Pocket`

- **`ReturnPad`:** 4x0.3x4, non-colliding, at `origin + (10, 0.15, 29)`, 10 studs east of the
  arena's own exit pad. It has the prompt "Back to the beach" / "Surface", 0.3 s hold, 8-stud
  range.
- **Lighting rig:** described below.

### Lighting rig (`Pocket/Backdrop`, `Pocket/Lights`)

The arena floor top is at Y 970, about 54 studs under the 16-stud slab. Sun and sky light
can't reach it, and from inside you would see the sky through the open sides and underneath.

The rig turns the space into an enclosed "room":

- Inside a closed box, Roblox lights the space with `Lighting.Ambient` (95, 95, 110) instead
  of `OutdoorAmbient`.
- A few warm PointLights lift the play space.
- `Exposure -0.3` and the bloom threshold are global and unchanged.

Every rig part:

- is anchored;
- has `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` set to false (World `Util.Part`
  with `Decor = true`), so the camera, raycasts and touches ignore it;
- is tagged and has the `ProtectedGeometry` attribute.

The light anchors are 1x1x1 parts with `Transparency = 1`.

Tunable values are in `AdventureEntry.LIGHTING`. Offsets are from the arena origin
(-200, 970, 106).

| Value | Default | Notes |
|---|---|---|
| `BackdropColor` / `BackdropMaterial` | (58, 50, 46) / Slate | Dark wet-sand cave. All five backdrop parts use it |
| `CeilingY` | +17 | Ceiling 140x1x166. Gate tops are at +10.4. The lowest slab terrain (dune balls) is at about +20 |
| `FloorY` | -31 | Underside plane (hides the sky below the floor) |
| `HalfX` | 70 | Side walls at x ±70; the arena walls are at ±49 |
| `ZMin` / `ZMax` | -106 / +60 | The far side is the dig strip's terrain face (world z 0), so it needs no wall. The near wall is at +60 (world z 166); terrain is clear to about +62 |
| `Lights` | 6 at x ±24, z +20 / -30 / -80 | Lobby, vault/anchors, ball channel and gates |
| `LightY` | +14 | Above the gate tops |
| `LightColor` | (255, 236, 210) | Warm |
| `LightBrightness` | 1.6 | |
| `LightRange` | 48 | Max 60. Neighbouring ranges overlap, so the floor has no dark band |
| `Shadows` | false on every light | Keeps cost down |

**Cost:** 11 parts (5 backdrop, 6 anchors) and 6 shadowless PointLights.

**Tuning guide for the Studio pass:**

- If the arena reads too dark, raise `LightBrightness` (1.6 → 2.2) before adding lights.
- If the walls read as a flat box, lighten `BackdropColor`, or switch to `Rock` and keep it dark.
- If the space is lit but grey, add a client-side `ColorCorrection` while in the arena. That
  would be a client change, not made here.

## Return paths

Every path lands on `SURFACE_RETURN`: `(-112, 1030.5, 76)`, on the sand 12 studs east of the
hatch, facing the plaza. It is a fixed server-side point. The server records it as the
player's return frame when they enter. It is never taken from the character's position, because
the client owns that.

| Trigger | What happens |
|---|---|
| Return pad | If the player is an active participant, the entry first calls `runtime.Handle(player, { action = "Leave", eventInstanceId })`. The runtime's restore then runs now, not later from the beach. Then the player goes to the surface and gets the toast "Back on the beach." The prompt is ignored unless the player stands inside the arena box |
| Runtime Leave, or the end of a run (`resetEvent`) | The runtime restores players to their arena join point (`returns[player]`). The entry sees the change from active participant to not, waits `LEAVE_DELAY` (0.6 s) so the runtime's own restore finishes, and lifts the player to the surface if they are still in the pocket. A player Left by the runtime's `tick` is covered too |
| Fall | The trigger is being below `origin.Y - 20` inside the pocket column (x ±100, world z 0..200, which excludes every dig hole at z ≤ -8). The player goes to the surface on the next check (0.2 s). The exception is a present participant during the ball stage: the runtime's own checkpoint recovery (2 s) gets `FALL_GRACE` (3 s) first. Falling off the open near edge of the arena is covered by the same rule |
| Kill switch `AdventureBoot.Disable()` | The runtime's `Destroy()` restores joined players into the arena and then removes it. `AdventureEntry.Stop()` runs right after, in the same frame, and lifts everyone in the pocket column to the surface. Then it destroys the folder and disconnects everything |
| Respawn | `BeachService.OnPlayerAdded` pivots every new character to `World.GetSpawnCFrame()` (boardwalk). With the scene spawn gone, Roblox only picks hub spawns anyway. Verified in the spec |
| Q / HUD "ReturnToSurface" | `BeachService.TeleportToSurface` calls `World.GetSurfacePoint(root)`. From the pocket (x -250..-150) that is the boardwalk deck at the same X (z 4, Y 1030.5). The spec verifies a collidable deck part is under that point, so no code change is needed. It is not the hatch, but it is a sane, safe landing spot |

**Ineligible players:** `AdventureEligibility.CanEnter` is false, so they are not moved. They get
the toast "Spring Vault opens after your Rookie certificate, or once you have sold sand and dug
up a deposit." A save that is still loading gets "Your save is still loading. Try the Spring
Vault again in a moment."

**Seated players:** they get "Hop off your ride first."

**Server-authoritative checks:**

- Both prompts have a 1.5 s per-player cooldown. Entry also has an in-flight guard while
  `RequestStreamAroundAsync` yields.
- A trigger only counts if the root is within 16 studs of the hatch, or inside the arena box for
  the return pad.
- After the stream yield, the server checks again that the player is still in the game, has the
  same character, is alive, and that the entry is still running.

**Cleanup:** `PlayerRemoving` clears per-player state. `Stop()` disconnects the Triggered,
PlayerRemoving and Heartbeat connections and destroys every instance it built.

## Test evidence (headless mock, 9 Oct 2026, luau 0.640, Windows)

| Spec | Result |
|---|---|
| adventure-entry `off` | 16 passed |
| adventure-entry `on` | 69 passed |
| production-wiring `off` | 37 passed (was 36) |
| production-wiring `on` | 40 passed (was 38) |
| production-wiring `rejoin` | 13 passed |
| production-wiring `client` | 20 passed |
| trophy-wired | 35 passed |
| trophy | 400 passed |
| adventure-settlement | 275 passed |
| adventure-outcome | 23 passed |
| smoke (live) | 2212 passed |
| smoke (Studio) | 2179 passed |
| persistence-boot (live and Studio) | pass |
| client | 1500, plus the 7 tutorial scenarios (14 + 13 + 12 + 10 + 10 + 14 + 16) |
| util | 8 |
| Codex spring-vault | 22 tests |
| Codex broadwave-dig | 23 |
| adventure-trophy-contract | 24 |
| `rojo build default.project.json` | succeeds |
| StyLua `--check` (LF-normalised) on the 4 changed Luau files | clean |
| `luau-lsp analyze` with a rojo sourcemap on `AdventureEntry`, `AdventureBoot` | clean |

**`adventure-entry on` covers:**

- the entrance prompt at the surface on the hatch;
- the entrance's location relative to the dig zone, camp pad, map parts and spawns;
- no SpawnLocation under the scene, and none enabled anywhere under the slab;
- the rig: no collidable parts, query and touch off, all protected, 6 shadowless lights, and its
  box free of map parts and terrain voxels;
- an ineligible player: refused, not moved, one toast (debounced);
- a trigger from far away: ignored;
- a certified player and a veteran catch-up player: land in the presence box, on the floor, near
  but not on Mara, clear of targets;
- the return pad, both as a visitor and as a participant (the participant is Left and is not
  pulled back down 2 s later);
- the return prompt is ignored on the surface;
- runtime Leave: the runtime restores the player into the arena, then the entry lifts them to the
  beach;
- a fall through the floor, and a fall off the open near edge;
- the ball-stage grace: the entry leaves the player alone and the runtime recovers them to its
  checkpoint;
- Q from the pocket: boardwalk deck at the pocket's X, with a deck part under it;
- respawn: lands on a boardwalk spawn;
- a run that ends with nobody ready (about 45 s): the scene is rebuilt, the rebuilt scene has no
  SpawnLocation, and the crew is lifted to the beach;
- kill switch with a visitor and a participant in the arena: both are on the beach before any
  frame advances, the folder, prompts and lights are gone, and both are still on the beach 2 s
  later.

**Mutation checks** (each one reverted afterwards):

| Mutation | Checks that fail |
|---|---|
| Spawn not destroyed | 2 |
| Spawn re-enabled and neutral | 3 |
| No `Stop()` in `Disable` | 5 |
| No leave-transition rule | 2 |
| Return pad doesn't Leave first | 1 |
| No fall rule | 2 |
| No ball-stage grace | 3 |
| `CanEnter` bypassed | 3 |
| No distance check | 1 |

**Mocked, not verified:**

- physics (falling is simulated by pivoting);
- real ProximityPrompt distance and hold behaviour (the mock fires `Triggered` directly);
- streaming (`RequestStreamAroundAsync` is a mock no-op);
- network ownership timing of `PivotTo`;
- real players and devices.

The ball-stage grace test sets the event's phase and stage directly, to avoid hauling a ball
through the mock.

**Needs a Studio visual check by the lead:**

- the pocket lighting values above, and whether the backdrop hides the sky from every camera
  angle, including zoomed out at the near edge;
- the hatch, sign and deck look at the surface;
- the "Go down" prompt placement;
- the camera through the non-colliding ceiling when zoomed out (CanQuery is false, so it should
  pass through rather than pop in);
- whether the pocket is dark enough that `Exposure -0.3` needs a client-side tweak.

## Requests to Codex

These are written up instead of edited, because the files are Codex's.

### 1. `SpringVaultScene.Build` option `ReviewSpawn` (review H1, clean fix)

`src/server/Adventure/SpringVaultScene.luau:52` and `:76-87`:

```lua
export type BuildOptions = { ReviewSpawn: boolean? }
function Scene.Build(parent: Instance, origin: Vector3?, options: BuildOptions?)
	...
	if not options or options.ReviewSpawn ~= false then
		local spawn = Instance.new("SpawnLocation")
		... -- unchanged lines 77-87
	end
```

`src/server/Adventure/SpringVaultService.luau`:

- Add `ReviewSpawn: boolean?` to `export type Options` (lines 17-27).
- Pass `{ ReviewSpawn = opts.ReviewSpawn }` at both build sites: line 60 (`Start`) and line 305
  (`resetEvent`).

`AdventureBoot.Options` would then set `ReviewSpawn = false`. The AdventureBoot guard can stay
as a second layer.

### 2. A production return point for `restore`

Today the runtime returns players to the wrong place in two ways:

- `Join` records `returns[player] = character:GetPivot()` (`SpringVaultService.luau:395`), which
  is a point inside the arena.
- `restore` (`:151-169`, pivot at `:166`) pivots the *current* character there on Leave, end of
  run, PlayerRemoving and Destroy.

So a participant who pressed Q or respawned on the beach is pulled back into the pocket at the
end of the run. The entry then lifts them up again, so it is safe, but they are teleported
twice. Proposal:

```lua
-- Options
ReturnFrame: ((Player) -> CFrame?)?,
-- restore(player), replacing lines 165-167
local character = player.Character
local target = (opts.ReturnFrame and opts.ReturnFrame(player)) or returns[player]
local part = root(player)
if character and target and part and math.abs(part.Position.X - scene.Origin.X) <= 48
	and math.abs(part.Position.Z - (scene.Origin.Z - 36)) <= 69 then
	character:PivotTo(target)
end
```

`AdventureBoot` would pass `ReturnFrame = function() return AdventureEntry.SURFACE_RETURN end`.
Then `Destroy()` would send players straight to the beach, instead of into an arena that is
about to vanish.

### 3. Close the arena's open near side

`SpringVaultScene.luau:88-90` builds walls on the left, right and far sides only. The +Z edge
(floor to +34, exit pad at +29) is open to the void. The entry's fall rule catches anyone who
walks off, but a wall is better. Proposal, after line 90:

```lua
part("NearBoundary", V(100, 8, 2), point(0, 4, 33), Kit.Palette.Navy, true)
```

It spans z +32..+34 and leaves the exit pad (z 27..31) and the entry's return pad clear.

### 4. Production copy for the Join refusal

`SpringVaultService.luau:373` says "Review uses an explicit starter loan." In production the
entrance already refuses ineligible players, so this text should only show in review builds,
or match the production unlock text.

### 5. Client scene reference after a rebuild (not checked)

`AdventureController` passes the scene model to `SpringVaultClient.Start` once. `resetEvent`
replaces that model after every run. Please confirm that `SpringVaultClient` finds the new model
(for prompts and visuals) after a rebuild.

## Open decisions for the owner

1. **Pip's trial behind `CanEnter`.** The entrance admits only `CanEnter` players, as specified.
   Players who meet `CanTrial` but not `CanEnter` cannot reach Pip. Should the hatch also admit
   `CanTrial`?
2. **Auto-return at the end of a run.** Every crew member still in the pocket is lifted to the
   beach when they stop being a participant, including at the end of a run. Visitors who never
   joined stay until they use the pad or press Q. Is that the wanted feel, or should finished
   crews stay in the arena?
3. **Q from the pocket** lands on the boardwalk at the pocket's X (about x -200), not by the
   hatch. If the hatch is preferred, the minimal change is in `BeachService.TeleportToSurface`:
   `if AdventureEntry.InPocket(near) then model:PivotTo(AdventureEntry.SURFACE_RETURN) return end`.
   It is not made, because that file belongs to the beach owner and the current landing is
   safe.
