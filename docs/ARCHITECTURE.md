# Architecture Contract — Beach Dig Simulator

This is the binding contract between all contributors (human or agent). If you need to change
something here, say so in your final report instead of silently diverging.

## Toolchain
- Rojo 7 project: `default.project.json`. All code is Luau, `--!strict` at the top of every file.
- File naming: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
  A folder with `init.luau` becomes that ModuleScript.
- Format with StyLua (`stylua src`). Validate with `./tools/check.sh` (stylua check, luau-lsp
  strict typecheck against the Roblox API, rojo build). **It must print `ALL CHECKS PASSED`.**
- No external packages / Wally. No asset IDs we don't own: everything visual is built from Parts,
  Terrain, MeshParts-free primitives, UI instances, and built-in fonts. Sounds: use only
  `rbxasset://` built-ins or leave a clearly marked `SOUND_IDS` table in config with `0` placeholders.

## DataModel layout
| Rojo path | DataModel | Owner |
|---|---|---|
| `src/shared/Config/*` | `ReplicatedStorage.Shared.Config` | Game design |
| `src/shared/Remotes.luau` | `ReplicatedStorage.Shared.Remotes` | Server scripting |
| `src/shared/Types.luau` | `ReplicatedStorage.Shared.Types` | Game design |
| `src/shared/Util/*` | `ReplicatedStorage.Shared.Util` | Server scripting (Format, Signal, etc.) |
| `src/shared/Models/*` | `ReplicatedStorage.Shared.Models` | Modeling |
| `src/server/Main.server.luau` + `Services/*` | `ServerScriptService.Server` | Server scripting |
| `src/server/World/*` | `ServerScriptService.Server.World` | Map |
| `src/client/Main.client.luau` + `Controllers/*` | `StarterPlayerScripts.Client` | Client gameplay (UI agent) |
| `src/client/UI/*` | `StarterPlayerScripts.Client.UI` | UI |
| `marketing/*` | (not in game) | Thumbnails/marketing |

Never edit files owned by another area. If you need something from another area, code against
the interface described here.

## Core mechanic (fixed)
- Each server has **12 dig plots** along the beach (`Config.Plots`). On join a player is assigned a
  free plot; on leave the plot is refilled ("the tide washes it away") and freed.
- Each plot is a rectangular column of **smooth Terrain** going from the beach surface down
  through **layers** (`Config.Layers`), each layer a depth band with its own terrain Material,
  hardness, sand value, and loot table. Deepest layers are mythical (e.g. Lava, Crystal Caverns,
  Ancient Ruins, the Core).
- Digging: client clicks/taps terrain (or holds) → `Remotes.Dig:FireServer(position: Vector3)`.
  Server validates: inside player's own plot, within reach of character, cooldown per shovel
  speed, backpack not full, shovel power >= layer hardness. Then `Terrain:FillBall(pos, radius,
  Enum.Material.Air)` with radius from the shovel, awards sand (layer value × shovel multiplier ×
  pass/boost/pet/rebirth multipliers) into the backpack, rolls the layer loot table for treasure.
- Selling: touching the Sell stand (map tags a part with CollectionService tag `SellZone`) or the
  `SellAnywhere` game pass → backpack sand converts to Coins.
- Upgrades: shovels (power, speed, radius, multiplier) and backpacks (capacity) bought with Coins.
- Pets from eggs (Coins / Robux), equip up to N, give sand multiplier.
- Rebirth: reset coins/shovel/backpack for a permanent multiplier + rebirth tokens.
- Getting out of a deep hole: `Remotes.ReturnToSurface` (UI button) teleports to plot surface.
- Holes deeper than the plot bottom are impossible; the bottom layer is "The Core" (goal).

## Map interface (World agent)
`src/server/World/init.luau` returns a module with:
```lua
World.Build(): () -- builds the whole map once at server start (idempotent)
World.GetPlots(): { PlotInfo }  -- after Build
-- PlotInfo = { Id: number, Origin: CFrame (center of the surface, Y = surface height),
--              Size: Vector3 (X,Z footprint and total depth Y), SpawnCFrame: CFrame }
World.ResetPlot(id: number): () -- refill the plot column with layered terrain
```
Tags (CollectionService) the map must place: `SellZone` (touch part at sell stand), `ShovelShop`,
`BackpackShop`, `EggShop` (ProximityPrompt-bearing parts; client opens UI), `RebirthStatue`,
`LeaderboardCoins`, `LeaderboardDepth` (SurfaceGui-ready Parts, server fills them), `SpawnLocation`.
Layer depth bands and materials come from `Config.Layers` — the map must read them, not hardcode.

## Models interface (Modeling agent)
`src/shared/Models/init.luau` exposes builder functions returning fresh, anchored, unparented
Models with a `PrimaryPart`:
```lua
Models.Shovel(shovelId: string): Model      -- tool head/handle look per Config.Shovels[id].Look
Models.Pet(petId: string): Model            -- cute low-poly creature per Config.Pets[id].Look
Models.Egg(eggId: string): Model
Models.Treasure(treasureId: string): Model  -- for reveal pop-ups / viewports
Models.Prop(name: string): Model            -- "PalmTree","Umbrella","BeachTowel","Sandcastle",
  -- "Crab","Lifeguard Tower","Boardwalk Stall","Surfboard","BeachBall","Rock","Shell","Chest"
Models.ListProps(): { string }
```
Shovels are equipped as a `Tool` the server creates via `Models.Shovel` (Handle = PrimaryPart,
unanchored, welded). Pets follow the player, client-side animated.

## Remotes (all in `ReplicatedStorage.Shared.Remotes`, created by the server, waited on by client)
RemoteEvents (client → server unless noted):
- `Dig(position: Vector3)`
- `ReturnToSurface()`
- `BuyShovel(id: string)`, `EquipShovel(id: string)`
- `BuyBackpack(id: string)`, `EquipBackpack(id: string)`
- `HatchEgg(eggId: string, count: number)` (count 1 or 3; 3 requires pass)
- `EquipPet(uid: string)`, `UnequipPet(uid: string)`, `DeletePet(uid: string)`
- `Rebirth()`
- `ClaimDailyReward()`, `ClaimQuest(questId: string)`, `RedeemCode(code: string)`
- `SetSetting(key: string, value: any)`
- server → client: `DataChanged(data: PlayerData)` (full snapshot on join, then partial
  `{[key]=value}` deltas), `Notify(kind: string, text: string)`,
  `DigResult(result: DigResult)`, `TreasureFound(treasureId: string, rarity: string)`,
  `EggHatched(results: {string})`, `PlotAssigned(plot: PlotInfo)`
RemoteFunctions: `GetData(): PlayerData`
Shared module API:
```lua
Remotes.Get(name: string): RemoteEvent      -- server creates, client WaitForChild
Remotes.GetFunction(name: string): RemoteFunction
```

## PlayerData (persisted, `Types.PlayerData`)
```
Coins, Sand (in backpack), TotalSandDug, Rebirths, RebirthTokens, MaxDepth,
Shovel (equipped id), OwnedShovels {id=true}, Backpack (equipped id), OwnedBackpacks {id=true},
Pets { [uid] = {Id, Equipped} }, PetSlots, Treasures { [treasureId] = count },
Index { [treasureId] = true } (discovered collection), DailyStreak, LastDailyClaim,
Quests { [questId] = {Progress, Claimed} }, RedeemedCodes {code=true}, Settings {},
Boosts { [boostId] = expiresUnix }, PlayTime, FirstJoin, Version
```
Game pass ownership is NOT persisted in PlayerData — query `MarketplaceService` and cache.

## Monetization (Config.Monetization, ids are 0 placeholders until the owner creates them)
Game passes: VIP, 2x Sand, Sell Anywhere, Auto Dig, Lucky (2x treasure luck), Triple Hatch,
+Pet Slots, Mega Backpack. Developer products: coin packs, 15-min boosts (2x sand, 2x luck),
Skip-Rebirth, egg hatches. All purchases granted through one `ProcessReceipt` with
idempotent purchase history in DataStore. Premium players get a small perk (+10% sand)
and the server uses `Players.PlayerMembershipChanged`.

## Persistence
DataStore `PlayerData_v1`, session-locked via `UpdateAsync` with a lock timestamp, autosave
every 120s, save on leave and `game:BindToClose`. Works in Studio without API access (falls
back to in-memory and warns). OrderedDataStores `Leaderboard_Coins`, `Leaderboard_Depth`.

## Analytics
Use `AnalyticsService:LogOnboardingFunnelStepEvent` for the first-session funnel
(joined, first dig, first sell, first shovel, first egg, first rebirth) and
`LogEconomyEvent` for coin sources/sinks.

## Amendments after design phase (binding)
- Title: **Dig to the Core! Beach Simulator**. See `docs/GDD.md`.
- `Config.SURFACE_Y = 1024`; plot bottom is at Y=24. Never generate terrain below Y=0.
- Terrain material colours are global per material, so **each layer owns a unique terrain
  material** (see `Config.Layers`). Map scenery may only use Sand (Dry Sand colour), Water, Grass,
  LeafyGrass, Snow, Concrete, Asphalt, Cobblestone. Apply `Workspace.Terrain:SetMaterialColor`
  from `Config.Layers[i].Color` at build time (World owns this).
- `src/shared/Remotes.luau` and `src/shared/Util/Format.luau` exist (coordinator-written; server
  scripting may extend Util but must not rename Remotes API). Remotes adds:
  events `PromptPurchase(kind: "GamePass"|"Product", key: string)` (client asks server to prompt
  — or client may call MarketplaceService directly), `EventChanged(activeEventIds: {string})`
  (server → client); functions `GetPlot(): PlotInfo?`, `GetOwnedPasses(): {[key]: boolean}`.
  Server must call `Remotes.CreateAll()` before anything else.
- Monetization ids and `GROUP_ID` of 0 mean "not configured": hide/disable those buttons, never
  prompt a purchase for id 0.
- Use `Config` helpers (see `src/shared/Config/init.luau`) instead of re-deriving formulas.
