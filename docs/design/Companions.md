# Companions: digging pets and Construction Crates

Owner: Companions agent (v2.1). This replaces `Diggers.md`. The numbers live in
`src/shared/Config/Pets.luau` (pets, `Dig`, `VehicleKind`, `Rideable`) and
`src/shared/Config/Eggs.luau` (crates, `Kind = "Crate"`). If this file and Config disagree,
Config is right.

## What changed in v2.1 (owner playtest)
The Garage diggers followed the player, teleported under them and dug a hole under their feet.
The owner asked for one companion system, so the Garage is gone:
- The 12 construction vehicles are now **pets** (same ids as the old diggers). You hatch them
  from **Construction Crates**.
- **One pet inventory and one equip limit.** Vehicle pets compete with creature pets for slots.
- Every pet keeps its sand **Multiplier**. Pets with a `Dig` ability also dig on their own.
- Digging pets dig **their own spot on a ring around the owner, 6 to 16 studs away**. They never
  dig under the owner's feet, and they never teleport. They drive or walk to the spot.
- **Ride-on excavator:** `mega_excavator` is a Mythic pet with `Rideable = true`. It has a 0.5%
  weight in the Core Crate. The Ride agent handles riding it (`Services/RideService`).

## Slots
Equip slots = `PlayerData.PetSlots` (3) + `ExtraPetSlots` from every owned game pass
(`Stats.GetPetSlots`, client `State.GetPetSlots`):

| Source | Slots |
|---|---|
| Everyone | 3 |
| ExtraPets pass | +2 |
| AutoDig pass ("+1 Pet slot & auto-swing") | +1 (it was +1 digger slot) |
| **Max** | **6** |

The rebirth digger-slot milestones were dropped because pets never had them.

## Construction Crates
| Crate | Price (coins) | Unlocks at | Contents (weight, rarity) |
|---|---|---|---|
| Sandbox Crate | 1,000 | Shell Bed (layer 3) | Toy Sand Truck 65 C · Little Dump Truck 28 U · Mini Excavator 7 R |
| Quarry Crate | 75,000 | Sunken Shipwreck (6) | Skid Steer 65 C · Bulldozer 28 U · Backhoe Loader 7 R |
| Deep Mine Crate | 6,000,000 | Frozen Abyss (10) | Drill Rig 65 C · Mining Cart Drill 28 U · Tunnel Borer 7 R |
| Core Crate | 1,500,000,000 | Alien Hive (14) | Mole Machine 62 C · Lava Drill 30 R · Core Driller 7.5 L · **Mega Excavator 0.5 M** |

The first crate costs about the same as the old first digger (800). It comes right after the
Lifeguard Shovel, at roughly 6 to 8 minutes. Each crate opens a little after the egg of the same
tier. Every crate starts with a Common so luck boosts work the same as on eggs. Crates use the
normal hatch flow (`HatchEgg`, Triple Hatch, inventory limit, announcements).

## Dig stats (no levels)
"% shovel" compares the pet's sand/s (`SandMultiplier / Interval`) with the active sand/s of the
best shovel at the same Power (`SandMultiplier / Cooldown`). Both get the same multipliers, so
the ratio holds at any point in the game. Radius is kept at pet scale (4-stud digs; 8-stud for
the last two).

| Pet | Rarity | Multiplier | Power (deepest layer) | Interval | Sand × | % shovel |
|---|---|---|---|---|---|---|
| toy_truck | Common | 1.05 | 15 (Pirate Cove) | 3.0 | 2.25 | 10 % |
| dump_truck | Uncommon | 1.08 | 25 (Shipwreck) | 2.8 | 3.6 | 12 % |
| mini_excavator | Rare | 1.12 | 45 (Fossil Bed) | 2.6 | 6.4 | 14 % |
| skid_steer | Common | 1.15 | 80 (Bedrock) | 2.4 | 6.2 | 10 % |
| bulldozer | Uncommon | 1.2 | 140 (Crystal Caverns) | 2.3 | 10.8 | 12 % |
| backhoe | Rare | 1.3 | 250 (Frozen Abyss) | 2.2 | 18.5 | 14 % |
| drill_rig | Common | 1.4 | 450 (Ancient Ruins) | 2.0 | 18 | 10 % |
| mining_drill | Uncommon | 1.55 | 800 (Magma Chamber) | 1.9 | 32 | 12 % |
| tunnel_borer | Rare | 1.75 | 1,400 (Obsidian) | 1.8 | 56 | 14 % |
| mole_machine | Common | 2 | 2,500 (Alien Hive) | 1.7 | 63 | 10 % |
| lava_drill | Rare | 2.4 | 2,500 (Alien Hive) | 1.6 | 77 | 13 % |
| core_driller | Legendary | 3 | 4,500 (The Core) | 1.5 | 140 | 15 % |
| mega_excavator | Mythic, Rideable | 4 | 4,500 (The Core) | 1.4 | 140 | 16 % |

Creature pets that dig a little (about 8 to 10 %): Sandy Crab (Power 4), Pirate Crab (25),
Mole (45), T-Rex (80), Crystal Golem (140), Lava Salamander (800) and Star Golem (2,500).

### Economy rules (kept from the Diggers design)
- **Digging pets supplement shovel digging. They never replace it.** Six slots of the best digger
  (16 %) total about 96 % of the active shovel rate. The smoke test asserts this.
- **Trade-off:** vehicle pets have smaller Multipliers than creature pets of the same tier. You
  give up multiplier to get digging. "Equip Best" still sorts by Multiplier.
- **Capacity is the real limiter.** Pet digs fill the same backpack and stop when it is full, so
  they make each trip fill faster without multiplying income.
- **Pets are kept on rebirth**, as before. A strong vehicle lets a fresh rebirth dig their current
  layer without the matching shovel, but only around the owner (at most about 6 studs below the
  owner's feet).

## Dig loop (server, `Services/PetDigService.luau`)
- **Tick:** every 0.1 s. Each digging pet digs once per `Dig.Interval`. Freshly equipped pets are
  staggered.
- **Active pets:** equipped pets with `Dig`, in the same order as the `EquippedPets` attribute
  (sorted ids), capped at the slot count. The 1-based index is the pet's **slot**.
- **When pets idle:**
  - The owner has no character or stands outside the dig zone.
  - The backpack is full. One "Your pets stopped digging" Info notify goes out per fill.
  - On `TooHard`, the pet backs off for 3 intervals. At most one notify per minute.
- **Picking a spot:**
  - The ring is 6 to 11 studs from the owner's feet, horizontally. A pet that carves 8-stud cubes
    uses a ring 3 studs further out.
  - Pet k of n starts at angle `k · 2π/n + 0.02 rad/s drift + its own shift`.
  - The spot is **stable**. The pet keeps digging it until one of these happens, and then it
    re-picks (shift += golden angle):
    - the spot leaves the ring because the owner walked away,
    - the spot leaves the dig zone,
    - the spot gets within 5 studs of another player,
    - the predicted carve box touches someone,
    - it is too deep (no solid ground within 6 studs below the owner's feet),
    - it is too hard.
- **Never under the owner:** `carveBox` predicts the voxel cube that `DigService` will carve,
  using the same grid maths. That cube must stay 1.5 studs clear of the owner's position and of
  every other player.
- **Deep in a hole:** if the ring point is inside the hole wall, the pet digs the wall at the
  owner's foot level, then one voxel lower. It checks with `ReadVoxels` that the voxel is solid.
  This widens the owner's hole at the owner's own layer.
- **The dig call:** `DigService.DigAt(player, point, { Power, Radius, SandMultiplier,
  Source = "Pet", Silent = true })`. `DigService` treats `"Pet"` and `"Ride"` like `"Digger"`:
  they have no shovel cooldown and use the 16-stud owner range. `SurvivalService` adds no heat
  for them, and `ShopService` sends no Scoop.
- **After a successful dig:** the server fires `PetDug(player, slot, petId, position, sandGained)`
  to all clients.

## Replication
- **Player attribute `EquippedPets`:** comma-separated sorted pet ids, published by `PetService`.
  It is the source of truth for followers.
- **Remotes:**
  - Removed: `BuyDigger`, `EquipDigger`, `UnequipDigger`, `UpgradeDigger`.
  - Renamed: `DiggerDug` is now `PetDug`.
  - Equip and unequip use `EquipPet` / `UnequipPet`.

## Save migration (`DataService`, `DATA_VERSION` 1 → 2)
- Each owned `data.Diggers[id]` becomes **one** vehicle pet with the same id. Upgrade levels are
  dropped: a level 5 digger gives the same single pet as a level 1 one.
- A digger that was equipped is equipped as a pet while the save's base `PetSlots` allow. The
  most valuable vehicles are equipped first.
- Converted pets may push a save over `PET_INVENTORY_LIMIT`. Nothing a player bought is lost.
- After the migration, `data.Diggers` is `{}`. The field stays in `PlayerData` and in
  `NewPlayerData` for type compatibility.

## Client
- **`PetFollowController`:**
  - Creatures trail in an arc, as before.
  - Vehicles (`Models.Pet` → `Models/Diggers` at `Look.Size`, about 3 to 5 studs) drive in a row
    behind them, snapped to the ground, and tuck in close inside deep holes.
  - On `PetDug`, the pet drives or walks to a park point 2.4 studs beyond its dig point, on the
    side away from the owner. Movement is capped at 28 studs/s, so there is no teleport. The pet
    then faces the hole and plays the dig animation:
    - vehicles move their `Motion` sub-Models (arm, bed, drill),
    - creatures do a scooping hop.
  - The pet stays parked while the owner stays put. It leaves after 4 s with no dig, or when the
    owner walks 6 studs away.
  - Burst, chunks, "+N" and the dig sound play for the owner.
- **`EggPanel`:**
  - Crates are listed with a crate swatch, a "Crate" tag, `Open 1/3` buttons and a "Construction
    Crate" header.
  - Each odds row shows "⛏ digs <layer> · every Ns", and "Rideable!" for the Mythic.
  - It also hooks the crate yard prompts.
- **`PetsPanel`:** ⛏ / 🚜 badges, plus dig stats and "🚜 Rideable" in the detail view. The Ride
  agent adds the ride button.
- **`HatchAnimation`:** for crates, the lid (sub-Model `Lid` of `Models.Egg`) pops off instead of
  the shell cracking.
- **HUD:** the Garage button is gone. The menu is 5×2 (10 buttons).

## World
The Garage building is gone. A **crate yard** stands in its place (`Layout.GARAGE`):
- a small arc of wooden pallets, one per crate, each tagged `CrateShop` with an `EggId` and an
  "Open" prompt,
- a "CONSTRUCTION CRATES" sign and traffic cones.

The egg arc builds pedestals only for non-crate eggs. That keeps its spacing, and it keeps the
tutorial's "nearest EggShop" arrow pointing at real eggs.

## v2.2: true odds, pity and Golden pets (Hatching and Compliance agent)

### True odds (Roblox policy)
Coins and Rebirth Tokens can be bought with Robux, so **every egg and crate is a paid random
item**. Every one shows the player's real odds, with every active modifier applied.
- **One function:** `Stats.GetHatchOddsList(egg, luck, pityCount)`, plus `Stats.GetHatchOdds`
  (the same odds as a map) and `Stats.RollHatch(egg, luck, pityCount, roll)`.
  - The server rolls with `RollHatch`, which is `Weighted.Pick` over `GetHatchOddsList`.
  - `EggPanel` shows `GetHatchOddsList` with `Stats.GetLuck(State.GetStatsContext())` and
    `PlayerData.Pity[egg]`. The two can't diverge.
- **Luck** (2x Luck boost from quests, daily rewards and codes, and Luck events; since v2.3 no pass sells luck) multiplies the weight of every
  non-Common pet.
- **What the panel shows:**
  - Odds are shown as `Format.Chance` values: 60%, 12.5%, 1.9%, 0.5%, 0.05%.
  - A gold note under the header lists the modifiers, e.g.
    "Includes your luck x2: 2x Luck x2".
  - The odds refresh on pass, boost, event and pity changes, and every second while the panel
    is open.
- **Reveal:** `EggHatched(petIds, { EggId, Chances, Pity })`. The hatch reveal shows a CHANCE row
  with the probability that pet really had.
- **Tests:**
  - `tests/smoke.spec.luau` "hatching + compliance" compares 200k server rolls with luck, 50k
    pity rolls and 100k crate rolls against the displayed odds (5 sigma).
  - `tests/client.spec.luau` checks that every panel row equals `Format.Chance(GetHatchOddsList(...))`.

### Pity (`EggDef.PityAt`, `PlayerData.Pity`)
After `PityAt` hatches in a row without a **Rare or better** pet (`Config.PITY_MIN_RARITY_ORDER = 3`),
the next hatch of that egg is guaranteed Rare+.
- **The guaranteed roll:** it picks among the Rare+ entries, using their (luck) weights.
- **The counter:** any Rare+ hatch resets it. Every hatch counts: paid, free, rewards, and each
  egg of a Triple Hatch.
- **Where it shows:**
  - The egg card says "Rare+ in N", or "Rare+ next hatch!".
  - The detail note says "Rare+ guaranteed in N hatches".
  - On the guaranteed hatch, the odds rows show the Rare+-only distribution.

| Egg / crate | Base Rare+ | PityAt | Streak reaches pity |
|---|---|---|---|
| Beach Egg | 2% | 40 | ~45% of the time (cheap starter egg) |
| Tide Pool, Pirate, Fossil, Crystal, Magma | 12% | 30 | ~2% |
| Cosmic Egg | 30% | 25 | almost never |
| Sandbox, Quarry, Deep Mine Crate | 7% | 35 | ~8% |
| Core Crate | 38% | 25 | almost never |
| Rebirth Egg, Golden Egg | 100% | none | n/a |

### Duplicate fusion and Golden pets
- **How to fuse:** in `PetsPanel`, select a pet with at least `Config.GOLDEN_FUSE_COUNT` (5)
  identical **non-golden** copies and press "Fuse 5 → Golden". This sends
  `FusePets(uid)`, which `PetService` validates.
- **What is consumed:** the selected pet plus 4 copies, unequipped copies first.
- **What you get:** one pet with `PetInstance.Golden = true`. It is equipped if any of the fused
  copies was equipped.
- **Golden pets can't be fused again.**
- **Golden bonuses:**
  - Its sand bonus `(Multiplier - 1)` is multiplied by `GOLDEN_SAND_BONUS` (1.5), in
    `Config.PetMultiplier(ids, golden)` and `Stats.GetPetMultiplier`.
  - A digging Golden pet digs `GOLDEN_DIG_SPEED` (1.25x) as often, via
    `Config.GetPetDigInterval` in `PetDigService`.
- **Replication:**
  - `EquippedPets` keeps sorted ids (`Stats.SortEquipped`: by id, normal before Golden).
  - `EquippedGolden` lists the 1-based Golden slots, e.g. "2".
  - `PetFollowController` and the PetsPanel preview tint Golden pets gold, with sparkles
    (`ModelFactory.MakeGolden`).
