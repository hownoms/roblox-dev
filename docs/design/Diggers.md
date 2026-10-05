# Diggers — design notes

Owner: Diggers agent (v2). Numbers live in `src/shared/Config/Diggers.luau` and the `DIGGER_*`
constants and helpers in `src/shared/Config/init.luau`. If this file and Config disagree, Config
is right.

## What a digger is
A digger is a small cartoon construction vehicle. It follows its owner around the beach and
auto-digs next to them. Diggers are a separate category from pets: pets keep the sand
multipliers, and diggers add extra digs.

- You buy diggers in the **Garage** at the hub (Panel `"Garage"`, map tag `"Garage"`), with coins.
  You can own one of each.
- **Upgrades:** levels 1 to 5. Each level makes the digger dig faster (`Interval × 0.94` per
  level, compounding) and get more sand (`+15 %` of base per level). Max level is about 2× the
  sand/second of level 1. Power and Radius never change.
- **Rebirths keep your diggers**, like pets (`Diggers` is not in `Config.Rebirths.Resets`). The
  late diggers need rebirths to buy.
- Diggers **never get Sunburnt**, which makes them feel valuable on hot days.

## Slots
| Source | Slots |
|---|---|
| Everyone | 1 |
| AutoDig game pass ("+1 Digger slot & auto-swing") | +1 |
| Rebirth 2 | +1 |
| Rebirth 5 | +1 |
| **Max** | **4** |

`Config.GetDiggerSlots(rebirths, hasAutoDigPass)`. Rebirth 2 is the first rebirth that feels like
a grind, so it gets a reward. Rebirth 5 is the mid-game. The pass slot is pure comfort: a player
without the pass reaches 3 slots by playing.

If a save has more diggers equipped than it has slots (for example, the pass check failed at
join), the server keeps the **most expensive** ones active. It does not unequip anything in the
save, so nothing is lost when the pass check recovers.

## Progression
Power matches the best shovel a player can afford at the digger's price. A new digger can
therefore dig the layer the player is in when they buy it. Sand/s is per unit of `SandValue`
(multiply by the layer's sand value). "% of shovel" compares against the active sand/s of the
shovel with the same Power (`SandMultiplier / Cooldown`).

| # | Digger | Price | Rebirths | Power (deepest layer) | Interval L1 → L5 (s) | Sand × L1 → L5 | Sand/s L1 → L5 | % of shovel L1 → L5 | All upgrades |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Toy Sand Truck | 800 | 0 | 15 (Pirate Cove) | 3.0 → 2.34 | 3 → 4.8 | 1.0 → 2.05 | 13 → 27 % | 3,440 |
| 2 | Little Dump Truck | 4K | 0 | 25 (Shipwreck) | 2.8 → 2.19 | 4.5 → 7.2 | 1.6 → 3.3 | 15 → 30 % | 17.2K |
| 3 | Mini Excavator | 15K | 0 | 45 (Fossil Bed) | 2.6 → 2.03 | 7 → 11.2 | 2.7 → 5.5 | 15 → 31 % | 65K |
| 4 | Skid Steer | 50K | 0 | 80 (Bedrock) | 2.4 → 1.87 | 9.5 → 15.2 | 4.0 → 8.1 | 15 → 31 % | 215K |
| 5 | Bulldozer | 200K | 0 | 140 (Crystal Caverns) | 2.3 → 1.80 | 14 → 22.4 | 6.1 → 12.5 | 15 → 32 % | 860K |
| 6 | Backhoe Loader | 800K | 0 | 250 (Frozen Abyss) | 2.2 → 1.72 | 20 → 32 | 9.1 → 18.6 | 15 → 31 % | 3.4M |
| 7 | Drill Rig | 3.5M | 1 | 450 (Ancient Ruins) | 2.0 → 1.56 | 27 → 43.2 | 13.5 → 27.7 | 15 → 30 % | 15M |
| 8 | Mining Cart Drill | 15M | 2 | 800 (Magma Chamber) | 1.9 → 1.48 | 40 → 64 | 21 → 43 | 15 → 31 % | 65M |
| 9 | Tunnel Borer | 80M | 4 | 1,400 (Obsidian Depths) | 1.8 → 1.41 | 60 → 96 | 33 → 68 | 15 → 31 % | 344M |
| 10 | Mole Machine | 450M | 6 | 2,500 (Alien Hive) | 1.7 → 1.33 | 95 → 152 | 56 → 115 | 15 → 31 % | 1.9B |
| 11 | Lava Drill | 1.5B | 8 | 2,500 (Alien Hive) | 1.6 → 1.25 | 120 → 192 | 75 → 154 | 20 → 41 % | 6.4B |
| 12 | Core Driller | 3.5B | 10 | 4,500 (The Core) | 1.5 → 1.17 | 140 → 224 | 93 → 191 | 15 → 31 % | 15.1B |

Upgrade costs are `UpgradeCosts[L]` = 0.4×, 0.7×, 1.2× and 2.0× the price, rounded to 2
significant digits. Maxing a digger costs 4.3× its price, which is about the price of the next
digger. Players then choose between "upgrade what I have" and "save for the next one".

The Lava Drill is the "best before the Core" digger. It has the same Power as the Mole Machine,
but it is a little faster, so a player at rebirth 8 has something to chase before the Core
Driller.

## Economy math
- **First digger is affordable at about 6–8 minutes.** It costs 800, which comes right after
  the Lifeguard Shovel (600, around 5.3 min in the GDD table) and before the Cooler (1,500, around
  8.4 min). Its Power 15 matches the Lifeguard Shovel, so it can dig in Pirate Cove, where the
  player is at that point.
- **Diggers supplement digging. They never replace it.** One digger at level 1 gives about 15 %
  of the equivalent shovel's active sand/s, and about 30 % at max level. Even with all 4 slots
  filled with the best 4 diggers at max level, the total stays under the active shovel rate:
  - R5: Tunnel Borer + Mining Cart Drill + Drill Rig + Backhoe, all at L5 ≈ 158 vs 223 for the
    Obsidian Drill (71 %).
  - R10: Core Driller + Lava Drill + Mole Machine + Tunnel Borer, all at L5 ≈ 528 vs 625 for the
    Core Breaker (84 %).
- **Capacity is the real limiter.** The economy is bounded by backpack capacity: a backpack fills
  in seconds, and income comes from sell trips. Diggers put their sand into the same backpack
  and stop when it is full. So they make each trip fill faster and help dig the hole deeper, but
  they cannot multiply income on their own. This is what keeps them safe to keep after a rebirth.
  After a rebirth, an old high-Power digger can carry a starter-shovel player deep, which feels
  great, but the bucket still caps every trip.
- **Sand per digger dig** = `layer.SandValue × digger SandMultiplier(level) × every other
  multiplier` (rebirth, pets, passes, boosts, events). `opts.SandMultiplier` replaces only the
  shovel factor in DigService.

## Dig loop (server, `DiggerService`)
- **Tick:** every 0.1 s. Each active digger digs once per `Interval`. Freshly equipped diggers
  are staggered so several never fire on the same frame.
- **When diggers idle:** the owner has no character, stands outside the dig zone (hub or
  boardwalk), or has a full backpack. A full backpack sends one gentle `Info` notify per fill.
- **Choosing the dig point:**
  - 35 % of digs land right under the owner's feet, which deepens their hole.
  - The rest land on a ring 2.5–4 studs out, which widens the hole. Successive digs step around
    the ring by the golden angle.
  - A dig point is skipped if it is within 5 studs (horizontal) of another player, or outside
    the dig zone.
  - The server raycasts down onto the terrain, at most 10 studs below the feet.
  - If the ray starts inside the hole wall, it digs the wall at foot level instead.
- **The dig call:** `DigService.DigAt(player, point, { Power, Radius, SandMultiplier,
  Source = "Digger", Silent = true })`.
- **After the dig:**
  - On success, the server fires `DiggerDug(player, diggerId, position, sandGained)` to all
    clients.
  - On `TooHard`, it sends at most one Info notify per minute.

## Replication contract
- **Player attribute `EquippedDiggers`:** `"id:level,id:level"`, listing the active diggers in
  Config order. It is `""` when none are active. A bare `"id"` also parses (level 1).
- **Player attribute `DiggerSlots`:** the current number of slots.
- **Remotes (client → server, `id: string`):** `BuyDigger`, `UpgradeDigger`, `EquipDigger`,
  `UnequipDigger`.
- **`DiggerDug` (server → all clients):** `(player, diggerId, position, sandGained)`. The 4th
  argument is an additive extension of the V2 contract.

## Client
- **`DiggerController`:**
  - Renders every player's diggers in a row behind the pets (9.5 studs back, 5 studs apart),
    snapped to the ground.
  - Diggers face where they drive and bob with the engine.
  - On `DiggerDug`, the digger drives to the hole, faces it and animates its moving parts. A
    layer-coloured burst plays at the dig point. The owner also sees `+N`, sand chunks and a soft
    dig sound.
  - Far-away diggers are hidden, and LowGraphics hides other players' diggers.
  - Hooks the `Garage` tag's ProximityPrompt to open the Garage panel.
- **`GaragePanel`:**
  - **Slot bar:** pips, plus hints for "+1 with Auto Dig" and "+1 at Rebirth N", and a "+1 Slot"
    pass button. The button only shows when the pass id is configured.
  - **Cards:** a ViewportFrame preview, with the camera framed from all 8 bounding-box corners
    so the vehicle fills the card. Each card also shows the level stars, the deepest layer it
    can dig, seconds per dig, sand ×, and the next level's stats.
  - **Buttons:** Buy, Equip/Unequip, and Upgrade/MAX.
  - **Tag:** "⭐ NEXT" marks the cheapest unlocked digger the player doesn't own yet.
- **`Models/Diggers.luau`:**
  - Chunky primitive vehicles with these silhouettes: dump bed, excavator arm and bucket, dozer
    blade, skid-steer bucket, backhoe and loader, drill mast, cart drill, borer cutter face, robot
    mole with twin drills, lava drill, golden core drill.
  - Moving parts are sub-Models (`Arm`, `Loader`, `Bed`, `Blade`, `Drill`, `Cutter`) with a
    `Hinge` PrimaryPart and the attributes `Motion` (`Swing` / `Tip` / `Spin` / `Drill`),
    `Amount` and `Plunge`. Any client can animate them generically.
  - Every part is anchored with CanCollide, CanQuery and CanTouch off, so diggers never block
    digging raycasts.
