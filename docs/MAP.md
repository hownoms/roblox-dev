# Map — Dig to the Core! Beach Simulator

Built procedurally at server start by `src/server/World` (deterministic, seed `20261005`).
All coordinates live in `src/server/World/Layout.luau`; this page mirrors them.

Axes: **+X = east, -X = west, +Z = inland (boardwalk/dunes), -Z = ocean.**
Surface `Y = 1024` (`Config.SURFACE_Y`), plot bottom `Y = 24`, nothing below `Y = 0`.
Water surface `Y = 1020`. Instances live under `Workspace.Map` (`Plots`, `Hub`, `Boardwalk`,
`Decor`, `Effects`, `Boundaries`, `CoreFloor`).

## Top-down layout

```
   Z
 +130  ~~~~~~~~~~~~~~~~~~~~~ grass dunes (scenery, outside boundary) ~~~~~~~~~~~~~~~~~~~~~
 +100  ===================================== north boundary ==============================
  +76                   [ DIG TO THE CORE! title sign ]   / giant shovel
  +72   palm    palm    palm    palm    palm     palm    palm    palm    palm    palm
  +62  |stall=====stall=====stall======== BOARDWALK deck =======stall=====stall=====stall|
  +46  |lamp====lamp====lamp====lamp===========================lamp====lamp====lamp=====|
  +42  +-----+  +-----+  +-----+      SHOVEL   LB$  LBm   BACKPACK      +-----+  +-----+  +-----+
  +28  | P9  |  | P5  |  | P1  |       hut     (14x18)      hut         | P2  |  | P6  |  | P10 |
  +14  +-sign+  +-sign+  +-sign+  flag          spawn          flag     +sign-+  +sign-+  +sign-+
    0  ==================== central cobblestone path ===( hub plaza r=30 )=====================
  -14  +-sign+  +-sign+  +-sign+  flag     spawn     spawn     flag     +sign-+  +sign-+  +sign-+
  -28  | P11 |  | P7  |  | P3  |   EGG ARC     SELL stand    REBIRTH     | P4  |  | P8  |  | P12 |
  -42  +-----+  +-----+  +-----+   (9 eggs)   [SellZone pad]  shrine     +-----+  +-----+  +-----+
  -47   umbrellas/towels  crabs  lifeguard  palm |pier| palm  sandcastle  lifeguard  umbrellas
  -64   ............ flat sand ends, beach slopes into the sea ...........|    |..................
  -78  ~~~~~~~~~~~~~~~~~~~~~~~~~ shoreline (rocks) ~~~~~~~~~~~~~~~~~~~~~~~~|    |~~~~~~~~~~~~~~~~~~
 -170  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ END PLATFORM ]~~~~~~~~~~~~~
 -194  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  gazebo/benches ~~~~~~~~~~~~~
 -200  ===================================== south boundary ==============================
        x: -154..-126 -116..-88 -78..-50   -50 ........ 0 ........ +50   50..78  88..116  126..154
```

Invisible boundary walls: `x = ±180`, `z = +100`, `z = -200` (Y 994..1114).

## Plots (`Config.PLOT_FOOTPRINT` 28, spacing 10, depth 1000)

Ids are ordered **nearest to the hub first**, so "first free plot" assignment keeps players close.
`Origin` = centre of the plot surface (Y 1024). `SpawnCFrame` = on the central path 4 studs in
front of the plot edge (Y 1027), looking into the plot.

| Id | Centre (X, Z) | X range | Z range | Spawn (X, Z) |
|---|---|---|---|---|
| 1 | (-64, 28) | -78..-50 | 14..42 | (-64, 10) |
| 2 | (64, 28) | 50..78 | 14..42 | (64, 10) |
| 3 | (-64, -28) | -78..-50 | -42..-14 | (-64, -10) |
| 4 | (64, -28) | 50..78 | -42..-14 | (64, -10) |
| 5 | (-102, 28) | -116..-88 | 14..42 | (-102, 10) |
| 6 | (102, 28) | 88..116 | 14..42 | (102, 10) |
| 7 | (-102, -28) | -116..-88 | -42..-14 | (-102, -10) |
| 8 | (102, -28) | 88..116 | -42..-14 | (102, -10) |
| 9 | (-140, 28) | -154..-126 | 14..42 | (-140, 10) |
| 10 | (140, 28) | 126..154 | 14..42 | (140, 10) |
| 11 | (-140, -28) | -154..-126 | -42..-14 | (-140, -10) |
| 12 | (140, -28) | 126..154 | -42..-14 | (140, -10) |

Each plot (`Workspace.Map.Plots.Plot_N`, attributes `PlotId`, `OwnerUserId`) has a colourful
frame just outside the footprint, corner posts, a rope ladder hanging 12 studs into the hole at
the outer front corner, and a `PlotSign` (attributes `OwnerName`, `PlotId`; SurfaceGui
"Plot N" + owner line) on the path side.

Underground: one layered terrain block per row (`x` -162..162, `|z|` 6..50, Y 24..1024), layer
bands from `Config.Layers` snapped to the 4-stud voxel grid. The walls between plots are the
same layers (the server restricts digging to plot columns). A glowing gold `CoreFloor` part at
Y 20..24 under both rows stops anyone falling out of the bottom.

## Hub stations

| Station | Position (X, Y, Z) | Tag / prompt |
|---|---|---|
| Spawns (3x `SpawnLocation`, 8x8, Neutral, face -Z) | (0,1024,4), (-9,1024,-3), (9,1024,-3) | `SpawnLocation` |
| Sell stand (faces spawn) | (0, 1024, -32) | pad `SellZone` (16x1x8 neon, CanTouch) at ≈(0,1024.5,-25.5) |
| Shovel hut | (-32, 1024, 29) | counter `ShovelShop` + prompt "Shop" |
| Backpack hut | (32, 1024, 29) | counter `BackpackShop` + prompt "Shop" |
| Leaderboard coins (14x18, front → spawn) | (-12, 1037, 38) | `LeaderboardCoins` |
| Leaderboard depth (14x18, front → spawn) | (12, 1037, 38) | `LeaderboardDepth` |
| Egg arc (9 pedestals, r = 19, 110°) | centre (-30, 1024, -48); eggs from (-45.6,-37) to (-14.4,-37) via (-30,-29) | each pedestal `EggShop`, attribute `EggId`, prompt "Hatch" (prompt also has `EggId`) |
| Rebirth shrine | (31, 1024, -29) | pedestal `RebirthStatue` + prompt "Rebirth" |
| Title sign "DIG TO THE CORE!" | (0, 1045, 76) faces south | — |
| Pier | x -6..6, z -42..-170, deck top Y 1025; end platform 28x24 at z -170..-194 | — |

## Events (visual)

`Workspace` attribute `ActiveEvents` (comma-separated ids, set by EventService) is watched; or
call `World.ApplyEvent({ ... })`.
- **HighTide**: `Map.Effects.TideSheet` rises from Y 1018.5 to 1023.4 and fades in over the
  lower beach/shallows (z -45..-240), waves grow, water deepens in colour.
- **GoldenHour**: `ClockTime` 14 → 17.8, warm tint, orange haze, stronger bloom.

## Thumbnail cameras

Set `workspace.CurrentCamera.CFrame` (Studio command bar, camera type Scriptable).

1. **Hub overview** (sunny, whole hub + pier + rows of plots):
   `CFrame.lookAt(Vector3.new(60, 1095, -150), Vector3.new(0, 1030, -5))`
   Wider alternative showing all 12 plots: `CFrame.lookAt(Vector3.new(0, 1180, -230), Vector3.new(0, 1020, 10))`
2. **Deep-hole shot** — dig Plot 1 down ~150–250 studs first (or run
   `workspace.Terrain:FillBlock(CFrame.new(-64, 924, 28), Vector3.new(24, 200, 24), Enum.Material.Air)`
   in Studio), then look down the shaft from its front edge so the layer bands show on the walls:
   `CFrame.lookAt(Vector3.new(-60, 1034, 13), Vector3.new(-66, 900, 36))`
   Inside-the-shaft variant: `CFrame.lookAt(Vector3.new(-60, 1000, 17), Vector3.new(-68, 840, 38))`
3. **Pier sunset** — `workspace:SetAttribute("ActiveEvents", "GoldenHour")`, wait ~8 s for the
   tween, then from the pier end looking back at the warm-lit beach and hub:
   `CFrame.lookAt(Vector3.new(-10, 1029, -196), Vector3.new(0, 1036, -60))`
   Out-to-sea variant (gazebo silhouette against the sky):
   `CFrame.lookAt(Vector3.new(4, 1028, -150), Vector3.new(-6, 1034, -260))`
