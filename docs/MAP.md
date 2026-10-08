# Map — Dig to the Core! Beach Simulator (v2: open beach)

Built procedurally at server start by `src/server/World` (deterministic, seed `20261005`).
All coordinates live in `src/server/World/Layout.luau`; this page mirrors them.

Axes: **+X = east, -X = west, +Z = inland (boardwalk / hub / dunes), -Z = ocean.**
Surface `Y = 1024` (`Config.SURFACE_Y`), bottom of the world `Y = 24`, nothing below `Y = 0`.
Water surface `Y = 1020`. Instances live under `Workspace.Map` (`Hub`, `Boardwalk`, `Decor`,
`Effects`, `CoreFloor`; boundaries in `Boardwalk/Boundaries`).

No plots: everyone digs in **one shared dig zone** along the shoreline. Max 16 players
(`Config.MAX_PLAYERS`; set it in Game Settings > Places, scripts can't).

## Top-down layout

```
   Z
 +170  ~~~~~~~~~~~~~~~~~~~~~~~ grass dunes (scenery) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 +130  ================================ north boundary =============================================
 +118                         [ DIG TO THE CORE! title sign ]  / giant shovel
 +108   palm   palm   palm   palm   palm          palm   palm   palm   palm   palm
  +92            EGG ARC (9)        LB$  LBdepth
  +72                                                     REBIRTH shrine
  +54                          ( hub plaza r=30, FOUNTAIN at centre )
  +44   CRATE YARD                                                      BEACH SHOP (+76,+40)
  +34          SHOVEL hut (-36)                       BACKPACK hut (+36)
  +28                               SELL stand (faces the sand), pad at z ~+21.5
  +12  |rail=================== BOARDWALK deck (spawns at z +4) ==== no rail |x|<96 =====rail|
   -4  |lamp====lamp====lamp====[DIG ANYWHERE!]====spawn spawn spawn====lamp====lamp==========|
   -8  +============================== DIG ZONE (inland edge) ===================================+
       |                       768 x 56 studs of diggable sand, x -384..+384                      |
  -64  +============================== DIG ZONE (sea edge) ======================================+
  -68  wet sand: umbrellas, towels, lifeguard towers, sandcastles, crabs   |pier|  ...
  -80  ....... flat sand ends, beach slopes into the sea ................|    |...................
  -95  ~~~~~~~~~~~~~~~~~~~~~ shoreline (rocks) ~~~~~~~~~~~~~~~~~~~~~~~~~~~|    |~~~~~~~~~~~~~~~~~~~
 -200  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[ END PLATFORM / gazebo ]~~~~~
 -232  ================================ south boundary =============================================
        x: -400 ................................... 0 ...................................... +400
```

Invisible boundary walls: `x = ±400`, `z = +130`, `z = -232`. Walk from the hub plaza centre
(z +50) to the sand (z -8) is ~58 studs (~3.5 s at WalkSpeed 16).

## Dig zone

| | Value |
|---|---|
| Footprint | x -384..384, z -64..-8 (768 x 56 studs) |
| `World.GetDigZone()` | `CFrame = CFrame.new(0, 1024, -36)`, `Size = (768, 1000, 56)` |
| Workspace attributes | `DigZoneCFrame` (CFrame), `DigZoneSize` (Vector3), for clients |
| Underground | one layered block x -392..392, z -72..0, Y 24..1024 (zone + 8-stud solid walls); layers 1-2 filled at build, deeper bands in the background (~100 frames, `WorldReady`) |
| Bottom | glowing-gold-ish `CoreFloor` part at Y 20..24 under the whole block |
| Zone corners | striped flags at x ±386 on both zone edges; "DIG ANYWHERE!" signs on the deck at x ±40, ±200 |

The server clamps every carve to the zone, so the walls (and the hub / seabed beyond them) never
break. The tide refills dug 8x8 columns (see BeachService).

## Hub stations

| Station | Position (X, Y, Z) | Tag / prompt |
|---|---|---|
| Spawns (3x `SpawnLocation`, 8x8, on the deck, face -Z) | pad centres (0,1027.5,4), (-14,1027.5,4), (14,1027.5,4) | `SpawnLocation` |
| Sell stand (faces the sand) | (0, 1024, 28) | pad `SellZone` (16x1x8, CanTouch) at ≈(0,1026.2,21.5) |
| Water fountain (plaza centre) | (0, 1024, 54) | basin `WaterFountain` + prompt "Drink" |
| Shovel hut | (-36, 1024, 34) | counter `ShovelShop` + prompt "Shop" |
| Backpack hut | (36, 1024, 34) | counter `BackpackShop` + prompt "Shop" |
| Construction Crate yard (four pallets; legacy `Layout.GARAGE` anchor) | (-78, 1024, 44) | each pallet `CrateShop`, attribute `EggId`, prompt "Open" |
| Beach Shop stall | (76, 1024, 40) | counter `BeachShop` + prompt "Shop" |
| Leaderboard coins / depth | (-14, 1037, 92) / (14, 1037, 92) | `LeaderboardCoins` / `LeaderboardDepth` (sign "TOP DIGGERS" / "DEEPEST"; boards cycle ALL TIME / THIS WEEK / THIS SERVER every 10 s) |
| Egg arc (9 pedestals, r = 19, 110°, bulging towards the plaza) | centre (-50, 1024, 92) | each pedestal `EggShop`, attribute `EggId`, prompt "Hatch" |
| Rebirth shrine | (44, 1024, 72) | pedestal `RebirthStatue` + prompt "Rebirth" |
| Title sign | (0, 1045, 118) faces south | — |
| Pier | x -6..6, z -68..-200, deck top Y 1025; end platform 28x24 at z -200..-224 | — |

Hub structures face the boardwalk spawns (`Layout.HUB_LOOK_TARGET = (0, 1024, 4)`).
`Layout.DECK_TOP` is 1027 (voxel surface + 2 visible-surface offset + 1). Spawn pad tops
are 1028; `World.GetSpawnCFrame` uses a standing root pivot at Y 1031.5.
`World.GetSurfacePoint(near)` = a pivot on the boardwalk deck (z +4, Y 1030.5) at `near.X`
(clamped to ±390), looking at the sand — used for spawns, ReturnToSurface and tide lifts.

## Events (visual)

`Workspace` attribute `ActiveEvents` (comma-separated ids, set by EventService) is watched.
- **HighTide**: `Map.Effects.TideSheet` rises over the dig zone and beach (z -8 .. -272), waves
  grow. BeachService lifts anyone in a hole to the boardwalk and refills every dug column.
- **GoldenHour**: warm late-afternoon light (Lighting.luau, Polish).

## Thumbnail cameras

Set `workspace.CurrentCamera.CFrame` (Studio command bar, camera type Scriptable).

1. **Beach overview** (sunny hub, boardwalk, the long dig strip and pier):
   `CFrame.lookAt(Vector3.new(90, 1110, -190), Vector3.new(0, 1024, 10))`
   Wider coastline: `CFrame.lookAt(Vector3.new(0, 1220, -330), Vector3.new(0, 1020, 0))`
2. **Deep-hole shot** — carve a shaft first (Studio: `/dig 250` while standing on the sand at x≈0,
   or run `workspace.Terrain:FillBlock(CFrame.new(0, 924, -36), Vector3.new(24, 200, 24), Enum.Material.Air)`),
   then look down it from the boardwalk side so the layer bands show on the walls:
   `CFrame.lookAt(Vector3.new(4, 1036, -18), Vector3.new(-2, 900, -40))`
   Inside-the-shaft variant: `CFrame.lookAt(Vector3.new(4, 1000, -26), Vector3.new(-4, 840, -44))`
3. **Pier sunset** — `workspace:SetAttribute("ActiveEvents", "GoldenHour")`, wait ~8 s, then
   from the pier end looking back at the warm-lit beach and hub:
   `CFrame.lookAt(Vector3.new(-10, 1029, -226), Vector3.new(0, 1036, -20))`
