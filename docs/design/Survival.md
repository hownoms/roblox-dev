# Survival: Heat, Shade and Snacks

Owner: Survival agent. The numbers live in `src/shared/Config/{Heat,Shades,Consumables,Boosts}.luau`. If this file and Config ever disagree, Config is the source of truth.

## Goal

The survival layer is a soft one. It gives players a reason to buy shade and drinks, move around the beach and stand together. It never punishes them: there is no damage and no death. At worst, a Sunburnt player digs more slowly until they cool down. A new player should not notice heat until they can afford the first umbrella.

## Heat

The server tracks heat for each player. It is not saved, ticks every 0.25 s and runs from 0 to 100 (`Heat.Max`).

| Where you are | Heat change per second |
|---|---|
| Underground (`Depth` >= 12 studs) | −2.5 |
| Under any placed shade (within its horizontal radius, at or above its ground) | −3 × the shade's `Cooling` (best shade wins) |
| On the hot sand in the sun (in the dig zone, in a shallow hole, or `FloorMaterial` Sand or the top two layer materials) | +0.45 × event multiplier, plus 0.12 per shovel dig (capped at +0.3/s) |
| Anywhere else (boardwalk, hub, swimming) | −1.5 |

- **Sunburnt:** you become Sunburnt at 100 and stay Sunburnt until heat drops to 40 (hysteresis, so the state does not flicker). DigService multiplies the dig cooldown by `SunburntCooldownMultiplier = 1.6`, which is about 62% dig speed.
- **Grace period:** while `PlayerData.PlayTime` is below 180 s, heat does not rise. The FTUE (first sell, first upgrades) stays heat-free, and the HUD shows 🧴 SAFE.
- **Events:** Golden Hour makes the sun hotter (×1.35). High Tide brings a sea breeze (×0.6).
- **Diggers:** digs with source `"Digger"` add no heat, because the owner may be standing still.
- **Fresh player, full sun, toy shovel at 2 digs/s:** 0.45 + 0.24 = 0.69/s, so the meter fills in about **145 s (about 2.4 min) of continuous digging**, or about 220 s standing still. In practice, sell trips across the boardwalk cool you on the way, so many players reach Sunburnt only on long dig sessions.
- **Fixes:** fountain water (−70) clears Sunburnt instantly (the fountain has a 3 s cooldown). A Beach Umbrella takes 100 → 40 in 20 s. Digging below 12 studs also cools you, so the core loop of digging deeper is itself a cure.

The server publishes these player attributes: `Heat` (rounded to 0.1), `Sunburnt`, `InShade`, `HeatZone` (`Sun` / `Shade` / `Underground` / `Cool`) and `HeatGrace`.

## Shade (Config.Shades)

| Shade | Price | Rebirths | Radius | Cooling | Fall/s | 100→40 in |
|---|---|---|---|---|---|---|
| Beach Umbrella | 120 | 0 | 6 | ×1.0 | 3.0 | 20 s |
| Striped Umbrella | 1,200 | 0 | 8 | ×1.4 | 4.2 | 14 s |
| Palm Tarp | 12K | 0 | 10 | ×1.8 | 5.4 | 11 s |
| Party Canopy | 100K | 0 | 12 | ×2.3 | 6.9 | 9 s |
| Tiki Cabana | 750K | 0 | 14 | ×2.8 | 8.4 | 7 s |
| Luxury Beach Tent | 6M | 1 | 17 | ×3.5 | 10.5 | 6 s |
| Royal Sand Pavilion | 80M | 3 | 21 | ×4.5 | 13.5 | 4 s |

- **Prices:** prices sit beside the shovel ladder in GDD §4. The umbrella (120) follows the trowel (30), pail (50) and spade (150), so it is the purchase at about 3–5 minutes, which is also when grace ends. Each later tier costs about 8–10× the one before and arrives about when the matching shovel tier does. The two top tiers are rebirth-gated prestige items.
- **Placement:** you buy a shade once (`OwnedShades`) and place it on the beach sand. Placing again moves it. Each player has 1 active shade, or 2 with the VIP pass; placing past the limit replaces the oldest. `PickUpShade` removes it, and it despawns when you leave. If the sand under it is dug away, the shade stays anchored where it was.
- **Server validation (SurvivalShades):**
  - You must own the shade.
  - The point must be within 30 studs horizontally of you.
  - It must be near the surface: no more than 6 studs below `SURFACE_Y`.
  - The ground is resolved from the terrain voxels: there must be solid, non-water ground within 4 studs below the client's raycast point. This rejects floating placements and placements over holes. The final Y is clamped to that voxel.
  - The point must be in the dig zone or on Sand or a layer material.
  - It must be at least 10 studs from hub stations (tagged parts) and at least 4 studs from another shade's pole.
  - No colliding part may block the pole area.
- **Shared cooling:** a shade cools **anyone** under it, which is a social, kid-friendly mechanic ("come stand under my tent!"). Bigger radii matter because friends dig around you.

## Snacks (Config.Consumables)

| Item | Price | Cooling | Boost |
|---|---|---|---|
| 💧 Fountain Water | free (fountain only, unlimited) | −70 | – |
| 🍋 Lemonade | 40 | −35 | – |
| 🥥 Coconut Water | 250 | −60 | – |
| 🍭 Popsicle | 1,200 | −50 | Sugar Rush (dig speed ×1.25) 30 s |
| 🍧 Shaved Ice | 6,000 | −80 | Sugar Rush 60 s |
| 🍉 Watermelon Slice | 25K | −100 | Melon Power (+50% sand) 45 s |
| 🍈 Giant Watermelon | 250K | −100 | Melon Power 150 s |

- **Buying and using:** `BuyConsumable(id, count 1..50)` adds to `PlayerData.Consumables`, up to 99 of each item. `UseConsumable(id)` uses one. A plain drink is refused if you are already at 0 heat, so kids do not waste items.
- **Boosts:** snack boosts stack time only up to 5 minutes (`ConsumableBoostCapSeconds`), so they cannot be bulk-stacked into a permanent buff. They are deliberately weaker than the Robux boosts (×1.25 speed, ×1.5 sand, against ×2) and are new boost ids (`SugarRush`, `MelonPower`), so Robux boost timers are untouched.
- **Cooler Pack** (developer product, `Id = 0` placeholder, 29 R$): 10 Coconut Water, 5 Shaved Ice and 3 Watermelon Slices. It is granted through the normal receipt path: `Main` calls `SurvivalService.GrantConsumables` after `RewardsService.Grant` (`Reward.Consumables`).

## Economy impact

- **New coin sinks:** shade tiers (one-off) and snacks (recurring and cheap) take a small share of income. The umbrella delays the first egg or bag by about 30–60 s, which is acceptable.
- **Income when unprepared:** an unprepared player in full sun loses at most about 38% dig speed for the 20–60 s it takes to walk to the fountain or dig deeper. A prepared player (umbrella placed, or the habit of digging deep) loses almost nothing.
- **Late game:** snack boosts are a "cheap at your depth" convenience. Melon Power uptime costs about 25K per 45 s, which is trivial late on. It is capped at 5 minutes of stacking, and +50% does not compete with the 2x Sand pass or product.
- **Robux:** the VIP pass gains "2 shades at once". The Cooler Pack is a small impulse product; every Robux item has a free path (the fountain, shade and digging deep).

## Client

- **SurvivalHUD** has its own ScreenGui, `Dig_Survival`, in the right-edge free region (y from 180 to bottom−150). It contains:
  - a thermometer with a fill colour from blue through yellow and orange to red, plus warning and Sunburnt tick marks;
  - a zone chip (☀️ / ⛱️ / 🕳️ / 🌴 / 🧴, or 🥵 BURNT with a pulsing bulb);
  - toasts for "getting hot" at 75, "Sunburnt! Find shade or drink water 💧" and "Cooled down";
  - a ⛱️ place button (F) and 3 snack quick-slots (keys 1, 2 and 3; these are the three most valuable owned snacks, cheapest first);
  - a Turn / Place / Cancel bar while placing.

  Screen warmth comes from a client-only `ColorCorrectionEffect` named `HeatTint` in Lighting plus a pulsing warm edge glow.
- **PlacementController** shows a translucent ghost and a radius disc that are green when valid and red otherwise. It raycasts against terrain only and uses the hit point, which is the visible smooth-terrain surface. Controls:
  - mouse pointer on desktop;
  - tap-to-aim on touch;
  - screen centre on gamepad;
  - R / L1 to rotate;
  - click / Place / R2 to place;
  - B / Backspace / Cancel to cancel.

  Digging is paused while placing and resumes only after the placing click is released.
- **BeachShopPanel** (Panel `"BeachShop"`) has Shade and Snacks tabs. Each card has a large model preview that fills the card. Shade cards show Buy, Place / Move and Pick Up; snack cards show Buy and x5. Buying a shade jumps straight into placement.
- **SurvivalController** handles the `WaterFountain` prompt (DrinkFountain), the `BeachShop` prompt (opens the panel) and the keybinds.

## Needs Studio verification

- How the shade models and viewport previews look, and how the canopy reads at real scale.
- That the ghost sits on the visible sand surface and not 2 studs inside it, and that the server Y clamp agrees.
- The `GetPartBoundsInBox` "something in the way" check against boardwalk planks, palms and decor.
- `Humanoid.FloorMaterial` values on the boardwalk and in the hub (they should not count as hot sand).
- How the HeatTint and edge glow feel, and whether the HUD fits on a phone.
