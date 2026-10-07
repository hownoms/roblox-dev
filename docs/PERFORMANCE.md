# Performance: budgets, profiling and the `/stress` test (v2.3)

## Studio diagnostic, 6 October 2026

Ran `/stress 15 fx` through DigTest chat for about 91 seconds, then `/stress stop` (bot cleanup and tide refill). Whole-run Output: **123.2 digs/terrain edits per second, 88% successful attempts, heartbeat 16.8 ms average / 253.3 ms maximum, reported memory 3,006 MB, send 55 kbps**. Ten-second windows after startup averaged 16.7 ms with maxima 19.5–32.9 ms, except one 42.1 ms spike; the first window had the 253.3 ms spike and 3,039 MB memory. These spikes and memory do not close the budgets below.

This was a Windows Studio server plus one local client, with two isolated gallery editors also open, automatic graphics and a 900×388 gameplay viewport. No phone, real populated server, client frame-time/memory/network capture or MicroProfiler trace was produced. The bots quickly dig deep; their GPU effects were not kept continuously in view. Reported memory is Studio's Stats value and needs an isolated-runtime baseline before attributing it to the game. Silent bots do not cover discovery reveals or actual client fan-out. Preserve these measurements as a diagnostic, not a shipping performance approval.

Goal: **a stable 30 FPS on a mid-range Android phone with 16 players digging** (the server
maximum). The target we want is 45–60 FPS. This page covers how to measure that, which numbers
to watch, and what costs we already know about.

## 1. Settings that matter

| Setting | Value | Where | Why |
|---|---|---|---|
| `Workspace.StreamingEnabled` | `true` | `default.project.json` | The map has about 4,800 parts (3,900 of them palms and props), and the dig strip is 768 studs long. A phone should only hold what is near it. |
| `StreamingMinRadius` | 64 | same | Always loaded around the player: the dig reach (20), the pet ring (6–12) and a full 16-stud dig, with room to spare. |
| `StreamingTargetRadius` | 320 | same | The hub (radius about 120 around x = 0) stays loaded from most of the beach. Pets render to 220 and nameplates to 60, so everything a player can see in detail is loaded. Lower it to 256 if memory is tight on low-end phones. |
| `StreamingIntegrityMode` | `MinimumRadiusPause` | same | The server teleports players about 1000 studs (from the bottom of a hole to the boardwalk, tide lifts, `/surface`). The player pauses until the ground around them has loaded, instead of falling through terrain that hasn't loaded yet. |
| `StreamOutBehavior` | `Opportunistic` | same | Parts beyond the target radius stream out even without memory pressure. This keeps phone memory flat on a long beach. Every client system handles stream-out (section 5). |
| Station models | `ModelStreamingMode = Atomic` | `Services/StreamingService` | A station's part, prompt, billboard and `EggId` arrive and leave together. |
| Ride vehicles, placed shades | `PersistentPerPlayer` + `AddPersistentPlayer(owner)` | `RideService`, `SurvivalShades` | The rider owns the vehicle's physics, and the shade owner's UI reads their own shades. Both are Atomic for everyone else. |
| `/stress` bots | `Atomic` | `DevCommands` | Same as other players' characters. |

## 2. Budgets

| Metric | Budget | Notes |
|---|---|---|
| Client frame time | **33.3 ms** (30 FPS) on mid Android; desired **16.7–22 ms** (45–60 FPS) | Watch the MicroProfiler's frame bar, not the FPS counter. Look for **spikes** as well as the average. |
| Server heartbeat | avg **< 16.7 ms** (60 Hz); max **< 33 ms** | `/stress` prints avg and max every 10 s. A heartbeat consistently over 16.7 ms means server physics and scripts are behind for everyone. |
| Network receive (client) | **< 100 KB/s** sustained with 16 diggers | Shift+F3 (Stats) or the Developer Console → Network. Spikes on joining are expected while the map streams in. |
| Client memory | **< 1.2 GB** total on a 3–4 GB Android | Developer Console → Memory. Watch the `PlaceMemory` / `Instances` / `Terrain` lines grow while you walk the whole beach. |
| Server memory | **< 3 GB** | `/stress` prints `Stats:GetTotalMemoryUsageMb()`. |

## 3. Running `/stress` (Studio only)

`/stress` is a chat command (see `src/server/Services/DevCommands.luau`).

```
/max                 best shovel and backpack (optional; the bots use the top shovel anyway)
/stress              15 bots (you + 15 = the 16-player server)
/stress 15 fx        same, plus a particle stream per bot (worst case for the GPU)
/stress 30           heavier than any real server, to find the ceiling
/stress stop         remove the bots, print the whole-run summary, refill every hole
```

What happens:
- `StressBot_1..N` are anchored R15-like dummies spread across the dig zone. Each has the top
  shovel model and **3 top digging pets** (real pet models from `Models.Pet`).
- Every bot digs with the **top shovel's stats at its cooldown** (Core Breaker: 16³-stud cube,
  every 0.12 s). That is about 8 digs/s per bot, the rate a client holding the dig button sends.
  Each pet digs at its own `Dig.Interval` on a 6–12 stud ring like `PetDigService`. A bot walks
  down its own hole, and after 6 failed digs (bottom reached, etc.) it moves to a new column.
- **Every dig is a real `DigService.DigAt`** for the player who ran `/stress`, with Source `"Ride"`
  (companion rules: no shovel cooldown, range measured from the bot) and `Silent = true`. So
  validation, `ReadVoxels`, the terrain carve, tide bookkeeping, sand and quests run through
  production code. Side effects land on your Studio save: your backpack is emptied whenever
  it is 90% full, and your MaxDepth and quests advance. Silent companion digs suppress
  discovery and treasure popups; exercise real-player finds/reveals separately.
- Every 10 s the Output shows:
  `[Stress] 15 bots | 150.2 digs/s (97% ok) | 150.2 terrain edits/s | heartbeat 9.8 ms avg / 21.4 ms max | memory 1430 MB | send 210 kbps`

What it does **not** simulate:
- **Real players' replication.** There are no 15 extra characters sending physics, and no
  remote fan-out to 15 other clients. The bots' anchored CFrame updates stand in for that.
- **Bot pets are server models.** Real pets are drawn by each client (`PetFollowController`), so
  bot pets send *more* CFrame traffic than real pets do.
- **Client dig visuals.** Scoops, bursts and "+N" text play for players only. Use `fx` for a GPU
  worst case.

Treat the result as an upper bound on the server cost of terrain and digging, and a fair
approximation on the client (terrain re-meshing, parts and particles near you).

## 4. Capturing the MicroProfiler

### Desktop (Studio or the Roblox app)
1. Start a test (Studio: **Test → Start** with 1 player, or publish to a private server).
2. Type `/stress` (or `/stress 15 fx`) in chat. Walk to the dig zone so the bots are in view.
3. Press **Ctrl+F6** (Cmd+F6 on Mac) to open the MicroProfiler. Press **Ctrl+P** to pause on a spike.
4. Use **Dump** (top menu → Dump → "1 frame" / "32 frames") to write an HTML capture to
   `%LOCALAPPDATA%\Roblox\logs\microprofile\` (Mac: `~/Library/Logs/Roblox/microprofile/`).
   Open it in a browser.
5. Server profile: open the Developer Console (**F9**) → **MicroProfiler** tab → *Server*, set the
   frame count and click **Start Recording**. The dump is saved on your machine.

### Mobile (a real Android phone, which is what matters)
1. Publish the place and join from the phone (the Roblox app).
2. Studio cannot run on a phone, so `/stress` cannot be started there: dev commands only run in
   Studio servers. Either use a **Team Test** in Studio and join the same server from the
   phone, or temporarily enable the command for your user id on a private server. **Never ship
   that.**
3. On the phone, open the in-game menu → **Settings → MicroProfiler: On**. The phone shows an
   address like `192.168.x.x:1338`.
4. On a computer on the **same Wi-Fi**, open that address in a browser. Pick a frame count and
   click **Capture**. The phone's frames download as an HTML dump.
5. Repeat with Graphics Quality set to *Automatic* and then forced down to 1–3, so you know the
   floor.

### What to look for in a dump
- **Frame bar over 33 ms on the phone:** expand the long frame. Common groups are `Render`
  (`Perform`, `Scene` and so on: too many parts or particles), `Physics` (unanchored assemblies),
  `Terrain` meshing (`updateTerrain`/`ClusterUpdate` after many carves), `Script` (our
  Heartbeat/RenderStepped loops: `PetFollowController.update`, `ShovelPoseController`,
  `GuideController`) and `Replicator`/`Network` (receive bursts).
- **Server:** `Heartbeat` time and the `Script` time inside it (DigService, PetDigService,
  BeachService tide steps, LeaderboardService), and `Terrain` writes from `FillBlock` and
  `FillBall`.
- **Spikes every 4 minutes** come from the tide refill (`BeachService.TideStep`, which refills
  columns from the bottom up). **Spikes every 60 s** come from leaderboard writes. Both run on
  the server.

## 5. Streaming-safe client code (rules)

Every client system must survive a part streaming **in late, out, and back in as a new
instance**:
- **CollectionService:** use `Client/Util/Tagged` (`Watch` / `WatchPrompts`). It handles
  `GetTagged` + `GetInstanceAddedSignal` + `GetInstanceRemovedSignal` and runs a cleanup on
  stream-out. Never keep a tagged part in a variable across frames.
- **Far targets** (guide beams, "go to the sell stand"): `GuideController.FindTagged(tag)`
  returns a tag target. Each frame it resolves to the nearest streamed-in part, or else to the
  server-published anchor (`ReplicatedStorage.WorldAnchors.<Tag>`, `Client/Util/Anchors`).
- **Workspace content:** never `WaitForChild` without a timeout. Read Workspace
  **attributes** (`DigZoneCFrame`, `ActiveEvents`, ...) for world facts, because attributes
  always replicate.
- **Other players:** their character parts may be missing (`Character.GetRoot(p) == nil`).
  Pets hide (`PetFollowController`), and nameplates re-attach to the current Head every 0.5 s
  (`StatusController.Reconcile`).
- **Server-rendered things** (leaderboards) are fine, because their SurfaceGuis stream with the
  board.

The headless tests simulate this: `Mock.StreamOut(inst)` destroys the client's copy (firing
`Destroying` and `InstanceRemoved`), and `Mock.StreamIn(token)` brings it back as a **new**
instance. See `tests/client.spec.luau`, section "streaming".

## 6. Known costs (audit, v2.3)

| Item | Cost | Notes |
|---|---|---|
| **Dig size** | 1 to 64 voxels per dig | Edge = `Radius × 2` rounded to 4-stud voxels. Hand Spade/Trowel (r ≤ 2.2): a `FillBall` dent (about 1 voxel). r 2.5–2.8: 4³ studs = 1 voxel. r 3.2–3.8: 8³ = 8 voxels. r 4.4–5.5: 12³ = 27 voxels. r 6–8: 16³ = 64 voxels (+1 voxel layer above the surface at the top). Each dig is one `FillBlock`, plus one `ReadVoxels` of 2³ voxels for validation. |
| **Dig rate** | Shovels: 0.5 s → 0.12 s cooldown. Pets: one dig per 1.4–2.8 s each, up to 6 equipped | Worst case per player: about 8 shovel digs/s + 6 pets × 0.7 = about 12 terrain edits/s, so **about 190/s for 16 players**. Clients re-mesh every changed terrain chunk in range. This is the biggest variable cost. |
| **Map parts** | about 4,790 BaseParts | Decor 3,904 (palm trees 2,048, crabs 480, umbrellas 320, shells 224, sandcastles 222, stalls 168, rocks 130, lifeguard towers 104), Hub 613 (crate yard 277, egg incubator 187), Boardwalk 271. With streaming, a player on the beach holds a slice of it. **Biggest easy win: palms are 16 parts each**; merge them into fewer parts or one mesh. |
| **GUIs / lights / emitters on the map** | 40 Surface/Billboard GUIs, 7 lights, 6 particle emitters | All in the hub, except boardwalk and decor signs. |
| **Pets** | 13–52 parts each (average 28) | 16 players × 6 pets × 28 = about 2,700 parts if everyone is in view. They are drawn client-side and hidden beyond 220 studs and when LowGraphics is on (other players' pets). |
| **Ride vehicle** | 93 parts | One per rider. Unanchored and constraint-driven, so it is real physics. |
| **Shades** | up to 160 parts (largest) | Up to 2 per player (VIP). |
| **Shovel tool** | up to 17 parts | One per character. |
| **Textures / meshes** | **none** | Everything is built from parts, so there are no asset downloads except sounds and the 1024² UI icon atlas. |
| **Per-frame client loops** | `PetFollowController` (RenderStepped, all pets), `ShovelPoseController` (Stepped, all characters, IK), `GuideController`, `StatusController` (0.5 s reconcile) | Check them in the `Script` group of the client dump. |

**If the phone misses 30 FPS with 16 diggers,** try these in order: lower the
`StreamingTargetRadius` (320 → 256 → 192). Merge the palm and crab parts. Throttle remote dig
bursts (other players' `PetDug` and `Scoop` effects beyond about 60 studs). Make LowGraphics also
hide other players' shovels and backpacks.
