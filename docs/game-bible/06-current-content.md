# 06 — Current content encyclopedia

Status: CURRENT SNAPSHOT, 8 October 2026. Generated from actual configuration, not the old GDD.

Every detected top-level named record is listed. Summary tables are navigation aids; the complete definition under each record includes nested loot weights, looks, requirements and rewards. The complete configuration snapshot in chapter 07 covers keyed tables, helper formulas and records without names/IDs. Luau expressions are preserved, not guessed or evaluated. Prices here are configuration values; live marketplace prices require a separate dashboard check.

## Backpacks — 13 records

| ID | Name | Price | Capacity | RebirthsRequired |
|---|---|---|---|---|
| bucket | Beach Bucket | 0 | 20 | 0 |
| sand_pail | Sand Pail | 50 | 60 | 0 |
| beach_bag | Beach Bag | 300 | 200 | 0 |
| cooler | Cooler | 1500 | 700 | 0 |
| treasure_sack | Treasure Sack | 7000 | 2500 | 0 |
| barrel | Pirate Barrel | 30000 | 9000 | 0 |
| mine_cart | Mine Cart | 130000 | 30000 | 0 |
| wheelbarrow | Wheelbarrow | 600000 | 100000 | 0 |
| dump_truck | Dump Truck | 3000000 | 400000 | 0 |
| sand_truck | Sand Truck | 18000000 | 1600000 | 1 |
| cargo_ship | Cargo Ship | 120000000 | 8000000 | 3 |
| black_hole_bag | Black Hole Bag | 900000000 | 50000000 | 6 |
| pocket_dimension | Pocket Dimension | 6000000000 | 400000000 | 9 |

### Beach Bucket (`bucket`)

```lua
{
		Id = "bucket",
		Name = "Beach Bucket",
		Price = 0,
		Capacity = 20,
		RebirthsRequired = 0,
		Description = "A trusty plastic bucket. Holds a little sand.",
		Look = {
			Color = rgb(60, 170, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Sand Pail (`sand_pail`)

```lua
{
		Id = "sand_pail",
		Name = "Sand Pail",
		Price = 50,
		Capacity = 60,
		RebirthsRequired = 0,
		Description = "Bigger bucket, bigger trips.",
		Look = {
			Color = rgb(255, 120, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Beach Bag (`beach_bag`)

```lua
{
		Id = "beach_bag",
		Name = "Beach Bag",
		Price = 300,
		Capacity = 200,
		RebirthsRequired = 0,
		Description = "Towel, sunscreen... and LOTS of sand.",
		Look = {
			Color = rgb(255, 90, 160),
			AccentColor = rgb(255, 240, 120),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	}
```

### Cooler (`cooler`)

```lua
{
		Id = "cooler",
		Name = "Cooler",
		Price = 1500,
		Capacity = 700,
		RebirthsRequired = 0,
		Description = "Keeps your sand nice and cool.",
		Look = {
			Color = rgb(40, 200, 230),
			AccentColor = rgb(255, 255, 255),
			Shape = "Box",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Treasure Sack (`treasure_sack`)

```lua
{
		Id = "treasure_sack",
		Name = "Treasure Sack",
		Price = 7000,
		Capacity = 2500,
		RebirthsRequired = 0,
		Description = "A pirate's loot bag, patched with gold thread.",
		Look = {
			Color = rgb(170, 120, 70),
			AccentColor = rgb(255, 210, 60),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	}
```

### Pirate Barrel (`barrel`)

```lua
{
		Id = "barrel",
		Name = "Pirate Barrel",
		Price = 30000,
		Capacity = 9000,
		RebirthsRequired = 0,
		Description = "Rum not included. Sand very included.",
		Look = {
			Color = rgb(140, 90, 50),
			AccentColor = rgb(80, 80, 90),
			Shape = "Barrel",
			Material = Enum.Material.Wood,
			Glow = false,
		},
	}
```

### Mine Cart (`mine_cart`)

```lua
{
		Id = "mine_cart",
		Name = "Mine Cart",
		Price = 130000,
		Capacity = 30000,
		RebirthsRequired = 0,
		Description = "Rolls on tiny rails strapped to your back.",
		Look = {
			Color = rgb(110, 110, 125),
			AccentColor = rgb(200, 60, 50),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Wheelbarrow (`wheelbarrow`)

```lua
{
		Id = "wheelbarrow",
		Name = "Wheelbarrow",
		Price = 600000,
		Capacity = 100000,
		RebirthsRequired = 0,
		Description = "Somehow fits on your back. Don't ask.",
		Look = {
			Color = rgb(60, 180, 90),
			AccentColor = rgb(60, 60, 60),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Dump Truck (`dump_truck`)

```lua
{
		Id = "dump_truck",
		Name = "Dump Truck",
		Price = 3000000,
		Capacity = 400000,
		RebirthsRequired = 0,
		Description = "A whole toy dump truck... that isn't a toy.",
		Look = {
			Color = rgb(255, 200, 30),
			AccentColor = rgb(50, 50, 60),
			Shape = "Vehicle",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Sand Truck (`sand_truck`)

```lua
{
		Id = "sand_truck",
		Name = "Sand Truck",
		Price = 18000000,
		Capacity = 1600000,
		RebirthsRequired = 1,
		Description = "The biggest truck on the beach. Requires 1 Rebirth.",
		Look = {
			Color = rgb(255, 130, 30),
			AccentColor = rgb(240, 240, 240),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Cargo Ship (`cargo_ship`)

```lua
{
		Id = "cargo_ship",
		Name = "Cargo Ship",
		Price = 120000000,
		Capacity = 8000000,
		RebirthsRequired = 3,
		Description = "Carry a shipyard of sand. Requires 3 Rebirths.",
		Look = {
			Color = rgb(40, 90, 200),
			AccentColor = rgb(230, 60, 60),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	}
```

### Black Hole Bag (`black_hole_bag`)

```lua
{
		Id = "black_hole_bag",
		Name = "Black Hole Bag",
		Price = 900000000,
		Capacity = 50000000,
		RebirthsRequired = 6,
		Description = "Bigger on the inside. Requires 6 Rebirths.",
		Look = {
			Color = rgb(80, 20, 140),
			AccentColor = rgb(255, 120, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```

### Pocket Dimension (`pocket_dimension`)

```lua
{
		Id = "pocket_dimension",
		Name = "Pocket Dimension",
		Price = 6000000000,
		Capacity = 400000000,
		RebirthsRequired = 9,
		Description = "An entire beach folded into a marble. Requires 9 Rebirths.",
		Look = {
			Color = rgb(255, 215, 90),
			AccentColor = rgb(120, 255, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```
## Badges — 15 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| Welcome | Welcome to the Beach! | — | — | — |
| FirstPet | New Best Friend | — | — | — |
| PirateCove | Arrr, Pirate Cove! | — | — | — |
| FossilBed | Dino Digger | — | — | — |
| CrystalCaverns | Crystal Clear | — | — | — |
| FrozenAbyss | Underground Ice Age | — | — | — |
| MagmaChamber | Too Hot to Handle | — | — | — |
| AlienHive | Close Encounter | — | — | — |
| TheCore | I Reached the Core! | — | — | — |
| FirstRebirth | Born Again | — | — | — |
| MythicLuck | Mythic Luck | — | — | — |
| Collector | Collector | — | — | — |
| AncientRuins | Lost Civilization | — | — | — |
| BeachRegular | Beach Regular | — | — | — |
| CoreBreaker | Core Breaker | — | — | — |

### Welcome to the Beach! (`Welcome`)

```lua
{ Key = "Welcome", Id = 305615989875213, Name = "Welcome to the Beach!", Kind = "FirstDig" }
```

### New Best Friend (`FirstPet`)

```lua
{ Key = "FirstPet", Id = 1399687731914868, Name = "New Best Friend", Kind = "FirstPet" }
```

### Arrr, Pirate Cove! (`PirateCove`)

```lua
{
		Key = "PirateCove",
		Id = 3721202346547107,
		Name = "Arrr, Pirate Cove!",
		Kind = "ReachLayer",
		Layer = "Pirate Cove",
	}
```

### Dino Digger (`FossilBed`)

```lua
{ Key = "FossilBed", Id = 1841450014262918, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" }
```

### Crystal Clear (`CrystalCaverns`)

```lua
{
		Key = "CrystalCaverns",
		Id = 3808710393122420,
		Name = "Crystal Clear",
		Kind = "ReachLayer",
		Layer = "Crystal Caverns",
	}
```

### Underground Ice Age (`FrozenAbyss`)

```lua
{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" }
```

### Too Hot to Handle (`MagmaChamber`)

```lua
{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" }
```

### Close Encounter (`AlienHive`)

```lua
{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" }
```

### I Reached the Core! (`TheCore`)

```lua
{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" }
```

### Born Again (`FirstRebirth`)

```lua
{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 }
```

### Mythic Luck (`MythicLuck`)

```lua
{ Key = "MythicLuck", Id = 0, Name = "Mythic Luck", Kind = "FindRarity", Rarity = "Mythic" }
```

### Collector (`Collector`)

```lua
{ Key = "Collector", Id = 0, Name = "Collector", Kind = "CompleteLayer" }
```

### Lost Civilization (`AncientRuins`)

```lua
{ Key = "AncientRuins", Id = 0, Name = "Lost Civilization", Kind = "ReachLayer", Layer = "Ancient Ruins" }
```

### Beach Regular (`BeachRegular`)

```lua
{ Key = "BeachRegular", Id = 0, Name = "Beach Regular", Kind = "DailyStreak", Count = 7 }
```

### Core Breaker (`CoreBreaker`)

```lua
{ Key = "CoreBreaker", Id = 0, Name = "Core Breaker", Kind = "Rebirth", Count = 10 }
```
## Boosts — 6 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| SandBoost | 2x Sand | — | "Double sand from every dig!" | — |
| LuckBoost | 2x Luck | — | "Double treasure chance and better pets from eggs!" | — |
| CoinBoost | 2x Coins | — | "Double coins every time you sell!" | — |
| SpeedBoost | Fast Dig | — | "Dig 50% faster!" | — |
| SugarRush | Sugar Rush | — | "Brain freeze! Dig 25% faster for a little while." | — |
| MelonPower | Melon Power | — | "Juicy! +50% sand for a little while." | — |

### 2x Sand (`SandBoost`)

```lua
{
		Id = "SandBoost",
		Name = "2x Sand",
		Kind = "Sand",
		Multiplier = 2,
		Description = "Double sand from every dig!",
		Color = rgb(255, 205, 60),
	}
```

### 2x Luck (`LuckBoost`)

```lua
{
		Id = "LuckBoost",
		Name = "2x Luck",
		Kind = "Luck",
		Multiplier = 2,
		Description = "Double treasure chance and better pets from eggs!",
		Color = rgb(90, 230, 120),
	}
```

### 2x Coins (`CoinBoost`)

```lua
{
		Id = "CoinBoost",
		Name = "2x Coins",
		Kind = "Coins",
		Multiplier = 2,
		Description = "Double coins every time you sell!",
		Color = rgb(255, 170, 30),
	}
```

### Fast Dig (`SpeedBoost`)

```lua
{
		Id = "SpeedBoost",
		Name = "Fast Dig",
		Kind = "Speed",
		Multiplier = 1.5,
		Description = "Dig 50% faster!",
		Color = rgb(60, 190, 255),
	}
```

### Sugar Rush (`SugarRush`)

```lua
{
		Id = "SugarRush",
		Name = "Sugar Rush",
		Kind = "Speed",
		Multiplier = 1.25,
		Description = "Brain freeze! Dig 25% faster for a little while.",
		Color = rgb(255, 120, 200),
	}
```

### Melon Power (`MelonPower`)

```lua
{
		Id = "MelonPower",
		Name = "Melon Power",
		Kind = "Sand",
		Multiplier = 1.5,
		Description = "Juicy! +50% sand for a little while.",
		Color = rgb(90, 220, 110),
	}
```
## Codes — 4 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| RELEASE | RELEASE | — | — | { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" } |
| SANDY | SANDY | — | — | { Boost = "SandBoost", BoostSeconds = 900 } |
| DIGDEEP | DIGDEEP | — | — | { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 } |
| 1KLIKES | 1KLIKES | — | — | { ScaledCoins = 600, RebirthTokens = 1 } |

### RELEASE (`RELEASE`)

```lua
{
		Code = "RELEASE",
		Reward = { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" },
		Enabled = true,
		Expires = nil,
		Note = "Launch code. Gives the exclusive Launch Party Crab.",
	}
```

### SANDY (`SANDY`)

```lua
{
		Code = "SANDY",
		Reward = { Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Expires = nil,
		Note = "Evergreen code shown on the loading screen / game description.",
	}
```

### DIGDEEP (`DIGDEEP`)

```lua
{
		Code = "DIGDEEP",
		Reward = { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 },
		Enabled = true,
		Expires = nil,
		GroupOnly = true,
		Note = "Group code: post it in the Roblox group and Discord.",
	}
```

### 1KLIKES (`1KLIKES`)

```lua
{
		Code = "1KLIKES",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = false,
		Expires = nil,
		Note = "Enable when the game reaches 1,000 likes.",
	}
```
## Consumables — 7 records

| ID | Name | Price | Cooling | Boost | BoostSeconds |
|---|---|---|---|---|---|
| water | Fountain Water | 0 | 70 | — | — |
| lemonade | Lemonade | 40 | 35 | — | — |
| coconut_water | Coconut Water | 250 | 60 | — | — |
| popsicle | Popsicle | 1200 | 50 | "SugarRush" | 30 |
| shaved_ice | Shaved Ice | 6000 | 80 | "SugarRush" | 60 |
| watermelon_slice | Watermelon Slice | 25000 | 100 | "MelonPower" | 45 |
| giant_watermelon | Giant Watermelon | 250000 | 100 | "MelonPower" | 150 |

### Fountain Water (`water`)

```lua
{
		Id = "water",
		Name = "Fountain Water",
		Price = 0,
		Cooling = 70,
		Icon = "💧",
		Description = "Free at the fountain! Cools you right down.",
		Look = { Style = "Bottle", Color = rgb(120, 200, 255) },
	}
```

### Lemonade (`lemonade`)

```lua
{
		Id = "lemonade",
		Name = "Lemonade",
		Price = 40,
		Cooling = 35,
		Icon = "🍋",
		Description = "Fresh and fizzy. A quick cool-down.",
		Look = { Style = "Cup", Color = rgb(255, 235, 90) },
	}
```

### Coconut Water (`coconut_water`)

```lua
{
		Id = "coconut_water",
		Name = "Coconut Water",
		Price = 250,
		Cooling = 60,
		Icon = "🥥",
		Description = "Straight from the palm tree. Big cool-down.",
		Look = { Style = "Coconut", Color = rgb(130, 85, 50) },
	}
```

### Popsicle (`popsicle`)

```lua
{
		Id = "popsicle",
		Name = "Popsicle",
		Price = 1200,
		Cooling = 50,
		Boost = "SugarRush",
		BoostSeconds = 30,
		Icon = "🍭",
		Description = "Brain freeze! Dig 25% faster for 30s.",
		Look = { Style = "Popsicle", Color = rgb(255, 90, 140) },
	}
```

### Shaved Ice (`shaved_ice`)

```lua
{
		Id = "shaved_ice",
		Name = "Shaved Ice",
		Price = 6000,
		Cooling = 80,
		Boost = "SugarRush",
		BoostSeconds = 60,
		Icon = "🍧",
		Description = "Rainbow syrup! Dig 25% faster for 60s.",
		Look = { Style = "ShavedIce", Color = rgb(90, 180, 255) },
	}
```

### Watermelon Slice (`watermelon_slice`)

```lua
{
		Id = "watermelon_slice",
		Name = "Watermelon Slice",
		Price = 25000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 45,
		Icon = "🍉",
		Description = "Fully cooled AND +50% sand for 45s.",
		Look = { Style = "Slice", Color = rgb(255, 80, 90) },
	}
```

### Giant Watermelon (`giant_watermelon`)

```lua
{
		Id = "giant_watermelon",
		Name = "Giant Watermelon",
		Price = 250000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 150,
		Icon = "🍈",
		Description = "A whole melon! Fully cooled AND +50% sand for 2.5 min.",
		Look = { Style = "Melon", Color = rgb(70, 170, 80) },
	}
```
## DailyRewards — 7 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| 1 | Coins | — | — | — |
| 2 | 2x Sand (15 min) | — | — | — |
| 3 | Big Coins | — | — | — |
| 4 | 2x Luck (15 min) | — | — | — |
| 5 | Free Eggs | — | — | — |
| 6 | Huge Coins + Token | — | — | — |
| 7 | Sunny Seal Pet! | — | — | { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 } |

### Coins (`1`)

```lua
{ Day = 1, Label = "Coins", Reward = { ScaledCoins = 120, Coins = 100 } }
```

### 2x Sand (15 min) (`2`)

```lua
{ Day = 2, Label = "2x Sand (15 min)", Reward = { Boost = "SandBoost", BoostSeconds = 900 } }
```

### Big Coins (`3`)

```lua
{ Day = 3, Label = "Big Coins", Reward = { ScaledCoins = 300, Coins = 250 } }
```

### 2x Luck (15 min) (`4`)

```lua
{ Day = 4, Label = "2x Luck (15 min)", Reward = { Boost = "LuckBoost", BoostSeconds = 900 } }
```

### Free Eggs (`5`)

```lua
{ Day = 5, Label = "Free Eggs", Reward = { Egg = "beach_egg", EggCount = 3 } }
```

### Huge Coins + Token (`6`)

```lua
{ Day = 6, Label = "Huge Coins + Token", Reward = { ScaledCoins = 600, Coins = 500, RebirthTokens = 1 } }
```

### Sunny Seal Pet! (`7`)

```lua
{
		Day = 7,
		Label = "Sunny Seal Pet!",
		Reward = { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 },
	}
```
## Eggs — 13 records

| ID | Name | Currency | Price | UnlockLayer | PityAt | Kind |
|---|---|---|---|---|---|---|
| beach_egg | Beach Egg | "Coins" | 100 | 1 | 40 | — |
| tidepool_egg | Tide Pool Egg | "Coins" | 2500 | 3 | 30 | — |
| pirate_egg | Pirate Egg | "Coins" | 40000 | 5 | 30 | — |
| fossil_egg | Fossil Egg | "Coins" | 600000 | 7 | 30 | — |
| crystal_egg | Crystal Egg | "Coins" | 8000000 | 9 | 30 | — |
| magma_egg | Magma Egg | "Coins" | 150000000 | 12 | 30 | — |
| cosmic_egg | Cosmic Egg | "Coins" | 3000000000 | 14 | 25 | — |
| rebirth_egg | Rebirth Egg | "Tokens" | 3 | 1 | — | — |
| golden_egg | Golden Egg | "Tokens" | 10 | 1 | — | — |
| sandbox_crate | Sandbox Crate | "Coins" | 1000 | 3 | 35 | "Crate" |
| quarry_crate | Quarry Crate | "Coins" | 75000 | 6 | 35 | "Crate" |
| mine_crate | Deep Mine Crate | "Coins" | 6000000 | 10 | 35 | "Crate" |
| core_crate | Core Crate | "Coins" | 1500000000 | 14 | 25 | "Crate" |

### Beach Egg (`beach_egg`)

```lua
{
		Id = "beach_egg",
		Name = "Beach Egg",
		Currency = "Coins",
		Price = 100,
		UnlockLayer = 1,
		PityAt = 40,
		Pets = {
			{ PetId = "sandy_crab", Weight = 60 },
			{ PetId = "seagull", Weight = 28 },
			{ PetId = "starfish", Weight = 10 },
			{ PetId = "baby_turtle", Weight = 1.9 },
			{ PetId = "golden_crab", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(255, 240, 200), SpotColor = rgb(80, 200, 255), Glow = false },
	}
```

### Tide Pool Egg (`tidepool_egg`)

```lua
{
		Id = "tidepool_egg",
		Name = "Tide Pool Egg",
		Currency = "Coins",
		Price = 2500,
		UnlockLayer = 3,
		PityAt = 30,
		Pets = {
			{ PetId = "clownfish", Weight = 60 },
			{ PetId = "pufferfish", Weight = 28 },
			{ PetId = "octopus", Weight = 10 },
			{ PetId = "sea_turtle", Weight = 1.9 },
			{ PetId = "rainbow_starfish", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(120, 220, 240), SpotColor = rgb(255, 150, 180), Glow = false },
	}
```

### Pirate Egg (`pirate_egg`)

```lua
{
		Id = "pirate_egg",
		Name = "Pirate Egg",
		Currency = "Coins",
		Price = 40000,
		UnlockLayer = 5,
		PityAt = 30,
		Pets = {
			{ PetId = "parrot", Weight = 60 },
			{ PetId = "pirate_crab", Weight = 28 },
			{ PetId = "ghost_blob", Weight = 10 },
			{ PetId = "skeleton_shark", Weight = 1.9 },
			{ PetId = "kraken", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(150, 100, 60), SpotColor = rgb(255, 210, 50), Glow = false },
	}
```

### Fossil Egg (`fossil_egg`)

```lua
{
		Id = "fossil_egg",
		Name = "Fossil Egg",
		Currency = "Coins",
		Price = 600000,
		UnlockLayer = 7,
		PityAt = 30,
		Pets = {
			{ PetId = "mole", Weight = 60 },
			{ PetId = "baby_raptor", Weight = 28 },
			{ PetId = "stegosaurus", Weight = 10 },
			{ PetId = "trex", Weight = 1.9 },
			{ PetId = "bone_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(230, 215, 180), SpotColor = rgb(140, 120, 90), Glow = false },
	}
```

### Crystal Egg (`crystal_egg`)

```lua
{
		Id = "crystal_egg",
		Name = "Crystal Egg",
		Currency = "Coins",
		Price = 8000000,
		UnlockLayer = 9,
		PityAt = 30,
		Pets = {
			{ PetId = "crystal_bat", Weight = 60 },
			{ PetId = "gem_blob", Weight = 28 },
			{ PetId = "crystal_golem", Weight = 10 },
			{ PetId = "frost_seal", Weight = 1.9 },
			{ PetId = "diamond_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(180, 120, 255), SpotColor = rgb(150, 240, 255), Glow = true },
	}
```

### Magma Egg (`magma_egg`)

```lua
{
		Id = "magma_egg",
		Name = "Magma Egg",
		Currency = "Coins",
		Price = 150000000,
		UnlockLayer = 12,
		PityAt = 30,
		Pets = {
			{ PetId = "lava_salamander", Weight = 60 },
			{ PetId = "magma_golem", Weight = 28 },
			{ PetId = "fire_bird", Weight = 10 },
			{ PetId = "lava_kraken", Weight = 1.9 },
			{ PetId = "phoenix", Weight = 0.09 },
			{ PetId = "core_dragon", Weight = 0.01 },
		},
		Look = { ShellColor = rgb(60, 30, 30), SpotColor = rgb(255, 100, 30), Glow = true },
	}
```

### Cosmic Egg (`cosmic_egg`)

```lua
{
		Id = "cosmic_egg",
		Name = "Cosmic Egg",
		Currency = "Coins",
		Price = 3000000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "alien_blob", Weight = 70 },
			{ PetId = "cosmic_turtle", Weight = 25 },
			{ PetId = "star_golem", Weight = 4.9 },
			{ PetId = "galaxy_dragon", Weight = 0.1 },
		},
		Look = { ShellColor = rgb(40, 30, 100), SpotColor = rgb(120, 255, 160), Glow = true },
	}
```

### Rebirth Egg (`rebirth_egg`)

```lua
{
		Id = "rebirth_egg",
		Name = "Rebirth Egg",
		Currency = "Tokens",
		Price = 3,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "tide_spirit", Weight = 70 },
			{ PetId = "rebirth_phoenix", Weight = 25 },
			{ PetId = "sandlantis_guardian", Weight = 5 },
		},
		Look = { ShellColor = rgb(120, 255, 200), SpotColor = rgb(255, 255, 255), Glow = true },
	}
```

### Golden Egg (`golden_egg`)

```lua
{
		-- v2.3: earnable only (was a Robux product). 10 Rebirth Tokens ~ 4 early rebirths.
		Id = "golden_egg",
		Name = "Golden Egg",
		Currency = "Tokens",
		Price = 10,
		UnlockLayer = 1,
		Pets = {
			{ PetId = "golden_seagull", Weight = 70 },
			{ PetId = "golden_turtle", Weight = 27 },
			{ PetId = "sun_dragon", Weight = 3 },
		},
		Look = { ShellColor = rgb(255, 210, 50), SpotColor = rgb(255, 255, 255), Glow = true },
	}
```

### Sandbox Crate (`sandbox_crate`)

```lua
{
		Id = "sandbox_crate",
		Name = "Sandbox Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1000,
		UnlockLayer = 3,
		PityAt = 35,
		Pets = {
			{ PetId = "toy_truck", Weight = 65 },
			{ PetId = "dump_truck", Weight = 28 },
			{ PetId = "mini_excavator", Weight = 7 },
		},
		Look = { ShellColor = rgb(214, 160, 96), SpotColor = rgb(255, 200, 40), Glow = false },
	}
```

### Quarry Crate (`quarry_crate`)

```lua
{
		Id = "quarry_crate",
		Name = "Quarry Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 75000,
		UnlockLayer = 6,
		PityAt = 35,
		Pets = {
			{ PetId = "skid_steer", Weight = 65 },
			{ PetId = "bulldozer", Weight = 28 },
			{ PetId = "backhoe", Weight = 7 },
		},
		Look = { ShellColor = rgb(150, 156, 168), SpotColor = rgb(255, 170, 30), Glow = false },
	}
```

### Deep Mine Crate (`mine_crate`)

```lua
{
		Id = "mine_crate",
		Name = "Deep Mine Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 6000000,
		UnlockLayer = 10,
		PityAt = 35,
		Pets = {
			{ PetId = "drill_rig", Weight = 65 },
			{ PetId = "mining_drill", Weight = 28 },
			{ PetId = "tunnel_borer", Weight = 7 },
		},
		Look = { ShellColor = rgb(110, 80, 60), SpotColor = rgb(255, 120, 30), Glow = false },
	}
```

### Core Crate (`core_crate`)

```lua
{
		Id = "core_crate",
		Name = "Core Crate",
		Kind = "Crate",
		Currency = "Coins",
		Price = 1500000000,
		UnlockLayer = 14,
		PityAt = 25,
		Pets = {
			{ PetId = "mole_machine", Weight = 62 },
			{ PetId = "lava_drill", Weight = 30 },
			{ PetId = "core_driller", Weight = 7.5 },
			{ PetId = "mega_excavator", Weight = 0.5 },
		},
		Look = { ShellColor = rgb(60, 60, 72), SpotColor = rgb(255, 210, 60), Glow = true },
	}
```
## Events — 2 records

| ID | Name | Kind | Multiplier | IntervalSeconds | DurationSeconds |
|---|---|---|---|---|---|
| HighTide | High Tide | "Luck" | 2 | 20 * 60 | 3 * 60 |
| GoldenHour | Golden Hour | "Coins" | 2 | 45 * 60 | 5 * 60 |

### High Tide (`HighTide`)

```lua
{
		Id = "HighTide",
		Name = "High Tide",
		Description = "The tide washes treasure into the sand! 2x Luck for everyone.",
		Kind = "Luck",
		Multiplier = 2,
		IntervalSeconds = 20 * 60,
		DurationSeconds = 3 * 60,
		OffsetSeconds = 0,
		Color = rgb(50, 170, 255),
	}
```

### Golden Hour (`GoldenHour`)

```lua
{
		Id = "GoldenHour",
		Name = "Golden Hour",
		Description = "The sunset makes everything shine. 2x Coins when you sell!",
		Kind = "Coins",
		Multiplier = 2,
		IntervalSeconds = 45 * 60,
		DurationSeconds = 5 * 60,
		OffsetSeconds = 10 * 60,
		Color = rgb(255, 160, 40),
	}
```
## Layers — 15 records

| ID | Name | DepthStart | DepthEnd | Hardness | SandValue | RewardScale |
|---|---|---|---|---|---|---|
| dry_sand | Dry Sand | 0 | 20 | 1 | 1 | 1 |
| wet_sand | Wet Sand | 20 | 45 | 2 | 2 | 1.5 |
| shell_bed | Shell Bed | 45 | 75 | 4 | 4 | 3 |
| tidal_clay | Tidal Clay | 75 | 110 | 8 | 8 | 8 |
| pirate_cove | Pirate Cove | 110 | 150 | 15 | 15 | 25 |
| shipwreck | Sunken Shipwreck | 150 | 200 | 25 | 30 | 80 |
| fossil_bed | Fossil Bed | 200 | 260 | 45 | 60 | 250 |
| bedrock | Bedrock | 260 | 330 | 80 | 120 | 450 |
| crystal_caverns | Crystal Caverns | 330 | 410 | 140 | 250 | 1200 |
| frozen_abyss | Frozen Abyss | 410 | 495 | 250 | 550 | 4000 |
| ancient_ruins | Ancient Ruins | 495 | 585 | 450 | 1200 | 15000 |
| magma_chamber | Magma Chamber | 585 | 680 | 800 | 2800 | 60000 |
| obsidian_depths | Obsidian Depths | 680 | 780 | 1400 | 6500 | 250000 |
| alien_hive | Alien Hive | 780 | 885 | 2500 | 16000 | 700000 |
| the_core | The Core | 885 | 1000 | 4500 | 40000 | 1800000 |

### Dry Sand (`dry_sand`)

```lua
{
		Id = "dry_sand",
		Name = "Dry Sand",
		DepthStart = 0,
		DepthEnd = 20,
		Material = Enum.Material.Sand,
		Color = rgb(255, 224, 150),
		Hardness = 1,
		SandValue = 1,
		TreasureChance = 0.04,
		LootTable = {
			{ TreasureId = "bottle_cap", Weight = 70 },
			{ TreasureId = "lost_flip_flop", Weight = 22 },
			{ TreasureId = "cool_sunglasses", Weight = 8 },
		},
		RewardScale = 1,
		FlavorText = "Warm, sunny and full of stuff tourists dropped. Every legend starts with a bucket!",
		AmbientColor = rgb(255, 236, 190),
	}
```

### Wet Sand (`wet_sand`)

```lua
{
		Id = "wet_sand",
		Name = "Wet Sand",
		DepthStart = 20,
		DepthEnd = 45,
		Material = Enum.Material.Sandstone,
		Color = rgb(214, 172, 112),
		Hardness = 2,
		SandValue = 2,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "seashell", Weight = 70 },
			{ TreasureId = "sand_dollar", Weight = 22 },
			{ TreasureId = "message_in_a_bottle", Weight = 8 },
		},
		RewardScale = 1.5,
		FlavorText = "Squishy, salty and perfect for sandcastles. The tide hides little gifts down here.",
		AmbientColor = rgb(230, 200, 150),
	}
```

### Shell Bed (`shell_bed`)

```lua
{
		Id = "shell_bed",
		Name = "Shell Bed",
		DepthStart = 45,
		DepthEnd = 75,
		Material = Enum.Material.Salt,
		Color = rgb(255, 214, 214),
		Hardness = 4,
		SandValue = 4,
		TreasureChance = 0.035,
		LootTable = {
			{ TreasureId = "conch_shell", Weight = 70 },
			{ TreasureId = "glowing_pearl", Weight = 25 },
			{ TreasureId = "giant_clam", Weight = 5 },
		},
		RewardScale = 3,
		FlavorText = "A million years of seashells packed together. Hold one to your ear... is that the Core humming?",
		AmbientColor = rgb(255, 210, 220),
	}
```

### Tidal Clay (`tidal_clay`)

```lua
{
		Id = "tidal_clay",
		Name = "Tidal Clay",
		DepthStart = 75,
		DepthEnd = 110,
		Material = Enum.Material.Mud,
		Color = rgb(150, 108, 82),
		Hardness = 8,
		SandValue = 8,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "rusty_anchor", Weight = 70 },
			{ TreasureId = "pocket_watch", Weight = 22 },
			{ TreasureId = "mermaid_comb", Weight = 8 },
		},
		RewardScale = 8,
		FlavorText = "Sticky clay that swallowed whole fishing boats. Something shiny is stuck in it.",
		AmbientColor = rgb(170, 130, 100),
	}
```

### Pirate Cove (`pirate_cove`)

```lua
{
		Id = "pirate_cove",
		Name = "Pirate Cove",
		DepthStart = 110,
		DepthEnd = 150,
		Material = Enum.Material.Ground,
		Color = rgb(122, 86, 56),
		Hardness = 15,
		SandValue = 15,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "gold_doubloon", Weight = 68 },
			{ TreasureId = "pirate_hook", Weight = 22 },
			{ TreasureId = "treasure_map", Weight = 9 },
			{ TreasureId = "pirate_chest", Weight = 1 },
		},
		RewardScale = 25,
		FlavorText = "Captain Sandbeard buried his loot here 300 years ago. His map says 'X marks... deeper'.",
		AmbientColor = rgb(140, 100, 60),
	}
```

### Sunken Shipwreck (`shipwreck`)

```lua
{
		Id = "shipwreck",
		Name = "Sunken Shipwreck",
		DepthStart = 150,
		DepthEnd = 200,
		Material = Enum.Material.WoodPlanks,
		Color = rgb(128, 88, 54),
		Hardness = 25,
		SandValue = 30,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "ships_wheel", Weight = 70 },
			{ TreasureId = "captains_spyglass", Weight = 26 },
			{ TreasureId = "cursed_skull", Weight = 4 },
		},
		RewardScale = 80,
		FlavorText = "The Salty Gull sank into the sand, not the sea. You're digging through its decks.",
		AmbientColor = rgb(110, 80, 55),
	}
```

### Fossil Bed (`fossil_bed`)

```lua
{
		Id = "fossil_bed",
		Name = "Fossil Bed",
		DepthStart = 200,
		DepthEnd = 260,
		Material = Enum.Material.Limestone,
		Color = rgb(228, 212, 176),
		Hardness = 45,
		SandValue = 60,
		TreasureChance = 0.03,
		LootTable = {
			{ TreasureId = "trilobite", Weight = 66 },
			{ TreasureId = "ammonite", Weight = 24 },
			{ TreasureId = "trex_tooth", Weight = 9 },
			{ TreasureId = "dino_skull", Weight = 1 },
		},
		RewardScale = 250,
		FlavorText = "Before the beach there was a jungle. Before the jungle there were DINOSAURS.",
		AmbientColor = rgb(220, 205, 170),
	}
```

### Bedrock (`bedrock`)

```lua
{
		Id = "bedrock",
		Name = "Bedrock",
		DepthStart = 260,
		DepthEnd = 330,
		Material = Enum.Material.Rock,
		Color = rgb(108, 110, 122),
		Hardness = 80,
		SandValue = 120,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "geode", Weight = 70 },
			{ TreasureId = "iron_nugget", Weight = 22 },
			{ TreasureId = "ancient_arrowhead", Weight = 8 },
		},
		RewardScale = 450,
		FlavorText = "Solid stone that most diggers never get past. Crack a geode and see what sparkles.",
		AmbientColor = rgb(100, 100, 115),
	}
```

### Crystal Caverns (`crystal_caverns`)

```lua
{
		Id = "crystal_caverns",
		Name = "Crystal Caverns",
		DepthStart = 330,
		DepthEnd = 410,
		Material = Enum.Material.Glacier,
		Color = rgb(176, 112, 255),
		Hardness = 140,
		SandValue = 250,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "amethyst", Weight = 66 },
			{ TreasureId = "sapphire", Weight = 24 },
			{ TreasureId = "glow_crystal", Weight = 9 },
			{ TreasureId = "rainbow_diamond", Weight = 1 },
		},
		RewardScale = 1200,
		FlavorText = "Glittering purple caves that glow in the dark. Nobody knows who lit them.",
		AmbientColor = rgb(150, 100, 230),
	}
```

### Frozen Abyss (`frozen_abyss`)

```lua
{
		Id = "frozen_abyss",
		Name = "Frozen Abyss",
		DepthStart = 410,
		DepthEnd = 495,
		Material = Enum.Material.Ice,
		Color = rgb(160, 226, 255),
		Hardness = 250,
		SandValue = 550,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "frozen_fish", Weight = 70 },
			{ TreasureId = "mammoth_tusk", Weight = 26 },
			{ TreasureId = "ice_crown", Weight = 4 },
		},
		RewardScale = 4000,
		FlavorText = "An underground ice age! Brr... a woolly mammoth is still frozen in here somewhere.",
		AmbientColor = rgb(170, 225, 255),
	}
```

### Ancient Ruins (`ancient_ruins`)

```lua
{
		Id = "ancient_ruins",
		Name = "Ancient Ruins",
		DepthStart = 495,
		DepthEnd = 585,
		Material = Enum.Material.Brick,
		Color = rgb(206, 176, 110),
		Hardness = 450,
		SandValue = 1200,
		TreasureChance = 0.025,
		LootTable = {
			{ TreasureId = "stone_tablet", Weight = 66 },
			{ TreasureId = "golden_idol", Weight = 26 },
			{ TreasureId = "sun_mask", Weight = 7 },
			{ TreasureId = "atlantis_crown", Weight = 1 },
		},
		RewardScale = 15000,
		FlavorText = "The lost city of Sandlantis. Its people dug down too... and never came back up.",
		AmbientColor = rgb(200, 170, 110),
	}
```

### Magma Chamber (`magma_chamber`)

```lua
{
		Id = "magma_chamber",
		Name = "Magma Chamber",
		DepthStart = 585,
		DepthEnd = 680,
		Material = Enum.Material.CrackedLava,
		Color = rgb(255, 92, 32),
		Hardness = 800,
		SandValue = 2800,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "obsidian_shard", Weight = 70 },
			{ TreasureId = "fire_ruby", Weight = 28 },
			{ TreasureId = "dragon_egg", Weight = 2 },
		},
		RewardScale = 60000,
		FlavorText = "Hot hot HOT! Rivers of lava light the way. Don't touch the glowing bits.",
		AmbientColor = rgb(255, 110, 50),
	}
```

### Obsidian Depths (`obsidian_depths`)

```lua
{
		Id = "obsidian_depths",
		Name = "Obsidian Depths",
		DepthStart = 680,
		DepthEnd = 780,
		Material = Enum.Material.Basalt,
		Color = rgb(52, 40, 72),
		Hardness = 1400,
		SandValue = 6500,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "shadow_gem", Weight = 70 },
			{ TreasureId = "void_pearl", Weight = 26 },
			{ TreasureId = "dragon_scale", Weight = 4 },
		},
		RewardScale = 250000,
		FlavorText = "Black glass, total silence. Strange footprints lead deeper... they aren't human.",
		AmbientColor = rgb(70, 50, 100),
	}
```

### Alien Hive (`alien_hive`)

```lua
{
		Id = "alien_hive",
		Name = "Alien Hive",
		DepthStart = 780,
		DepthEnd = 885,
		Material = Enum.Material.Slate,
		Color = rgb(96, 232, 124),
		Hardness = 2500,
		SandValue = 16000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "alien_goo", Weight = 66 },
			{ TreasureId = "ufo_part", Weight = 24 },
			{ TreasureId = "alien_artifact", Weight = 9 },
			{ TreasureId = "alien_egg", Weight = 1 },
		},
		RewardScale = 700000,
		FlavorText = "A crashed spaceship grew into a glowing green hive. The aliens were looking for the Core too.",
		AmbientColor = rgb(110, 240, 140),
	}
```

### The Core (`the_core`)

```lua
{
		Id = "the_core",
		Name = "The Core",
		DepthStart = 885,
		DepthEnd = 1000,
		Material = Enum.Material.Pavement,
		Color = rgb(255, 200, 60),
		Hardness = 4500,
		SandValue = 40000,
		TreasureChance = 0.02,
		LootTable = {
			{ TreasureId = "core_fragment", Weight = 75 },
			{ TreasureId = "molten_gold", Weight = 22 },
			{ TreasureId = "heart_of_the_earth", Weight = 2.9 },
			{ TreasureId = "beach_ball_of_creation", Weight = 0.1 },
		},
		RewardScale = 1800000,
		FlavorText = "The golden heart of the planet. Legends say the very first beach ball was made here.",
		AmbientColor = rgb(255, 210, 90),
	}
```
## Pets — 56 records

| ID | Name | Rarity | Multiplier | Exclusive | VehicleKind | Rideable | Dig |
|---|---|---|---|---|---|---|---|
| sandy_crab | Sandy Crab | "Common" | 1.05 | false | — | — | { Power = 4, Interval = 4, Radius = 2, SandMultiplier = 1 } |
| seagull | Seagull | "Common" | 1.08 | false | — | — | — |
| starfish | Starfish | "Uncommon" | 1.12 | false | — | — | — |
| baby_turtle | Baby Turtle | "Rare" | 1.2 | false | — | — | — |
| golden_crab | Golden Crab | "Legendary" | 1.5 | false | — | — | — |
| clownfish | Clownfish | "Common" | 1.15 | false | — | — | — |
| pufferfish | Pufferfish | "Uncommon" | 1.22 | false | — | — | — |
| octopus | Octopus | "Rare" | 1.3 | false | — | — | — |
| sea_turtle | Sea Turtle | "Epic" | 1.45 | false | — | — | — |
| rainbow_starfish | Rainbow Starfish | "Legendary" | 1.8 | false | — | — | — |
| parrot | Pirate Parrot | "Common" | 1.3 | false | — | — | — |
| pirate_crab | Pirate Crab | "Uncommon" | 1.4 | false | — | — | { Power = 25, Interval = 3.5, Radius = 2.2, SandMultiplier = 3 } |
| ghost_blob | Ghost Blob | "Rare" | 1.55 | false | — | — | — |
| skeleton_shark | Skeleton Shark | "Epic" | 1.75 | false | — | — | — |
| kraken | Kraken | "Legendary" | 2.3 | false | — | — | — |
| mole | Mole | "Common" | 1.5 | false | — | — | { Power = 45, Interval = 3, Radius = 2.2, SandMultiplier = 4.2 } |
| baby_raptor | Baby Raptor | "Uncommon" | 1.7 | false | — | — | — |
| stegosaurus | Stegosaurus | "Rare" | 1.9 | false | — | — | — |
| trex | T-Rex | "Epic" | 2.2 | false | — | — | { Power = 80, Interval = 2.8, Radius = 2.4, SandMultiplier = 7.2 } |
| bone_dragon | Bone Dragon | "Legendary" | 3 | false | — | — | — |
| crystal_bat | Crystal Bat | "Common" | 1.8 | false | — | — | — |
| gem_blob | Gem Blob | "Uncommon" | 2.1 | false | — | — | — |
| crystal_golem | Crystal Golem | "Rare" | 2.5 | false | — | — | { Power = 140, Interval = 3, Radius = 2.4, SandMultiplier = 12 } |
| frost_seal | Frost Seal | "Epic" | 3 | false | — | — | — |
| diamond_dragon | Diamond Dragon | "Legendary" | 4 | false | — | — | — |
| lava_salamander | Lava Salamander | "Common" | 2.5 | false | — | — | { Power = 800, Interval = 3, Radius = 2.4, SandMultiplier = 34 } |
| magma_golem | Magma Golem | "Uncommon" | 3 | false | — | — | — |
| fire_bird | Fire Bird | "Rare" | 3.5 | false | — | — | — |
| lava_kraken | Lava Kraken | "Epic" | 4.5 | false | — | — | — |
| phoenix | Phoenix | "Legendary" | 6 | false | — | — | — |
| core_dragon | Core Dragon | "Mythic" | 10 | false | — | — | — |
| alien_blob | Alien Blob | "Common" | 3.5 | false | — | — | — |
| cosmic_turtle | Cosmic Turtle | "Rare" | 5 | false | — | — | — |
| star_golem | Star Golem | "Epic" | 7 | false | — | — | { Power = 2500, Interval = 2.8, Radius = 2.6, SandMultiplier = 104 } |
| galaxy_dragon | Galaxy Dragon | "Mythic" | 15 | false | — | — | — |
| tide_spirit | Tide Spirit | "Rare" | 1.6 | false | — | — | — |
| rebirth_phoenix | Rebirth Phoenix | "Epic" | 2 | false | — | — | — |
| sandlantis_guardian | Sandlantis Guardian | "Legendary" | 3 | false | — | — | — |
| golden_seagull | Golden Seagull | "Epic" | 1.8 | false | — | — | — |
| golden_turtle | Golden Turtle | "Legendary" | 2.6 | false | — | — | — |
| sun_dragon | Sun Dragon | "Mythic" | 4.5 | false | — | — | — |
| sunny_seal | Sunny Seal | "Epic" | 1.5 | true | — | — | — |
| launch_crab | Launch Party Crab | "Rare" | 1.25 | true | — | — | — |
| toy_truck | Toy Sand Truck | "Common" | 1.05 | false | "ToyTruck" | — | { Power = 15, Interval = 3, Radius = 2.2, SandMultiplier = 2.25 } |
| dump_truck | Little Dump Truck | "Uncommon" | 1.08 | false | "DumpTruck" | — | { Power = 25, Interval = 2.8, Radius = 2.2, SandMultiplier = 3.6 } |
| mini_excavator | Mini Excavator | "Rare" | 1.12 | false | "Excavator" | — | { Power = 45, Interval = 2.6, Radius = 2.4, SandMultiplier = 6.4 } |
| skid_steer | Skid Steer | "Common" | 1.15 | false | "SkidSteer" | — | { Power = 80, Interval = 2.4, Radius = 2.4, SandMultiplier = 6.2 } |
| bulldozer | Bulldozer | "Uncommon" | 1.2 | false | "Bulldozer" | — | { Power = 140, Interval = 2.3, Radius = 2.6, SandMultiplier = 10.8 } |
| backhoe | Backhoe Loader | "Rare" | 1.3 | false | "Backhoe" | — | { Power = 250, Interval = 2.2, Radius = 2.6, SandMultiplier = 18.5 } |
| drill_rig | Drill Rig | "Common" | 1.4 | false | "DrillRig" | — | { Power = 450, Interval = 2, Radius = 2.8, SandMultiplier = 18 } |
| mining_drill | Mining Cart Drill | "Uncommon" | 1.55 | false | "MiningDrill" | — | { Power = 800, Interval = 1.9, Radius = 2.8, SandMultiplier = 32 } |
| tunnel_borer | Tunnel Borer | "Rare" | 1.75 | false | "TunnelBorer" | — | { Power = 1400, Interval = 1.8, Radius = 2.8, SandMultiplier = 56 } |
| mole_machine | Mole Machine | "Common" | 2 | false | "Mole" | — | { Power = 2500, Interval = 1.7, Radius = 2.8, SandMultiplier = 63 } |
| lava_drill | Lava Drill | "Rare" | 2.4 | false | "LavaDrill" | — | { Power = 2500, Interval = 1.6, Radius = 2.8, SandMultiplier = 77 } |
| core_driller | Core Driller | "Legendary" | 3 | false | "CoreDriller" | — | { Power = 4500, Interval = 1.5, Radius = 3.2, SandMultiplier = 140 } |
| mega_excavator | Mega Excavator | "Mythic" | 4 | false | "Excavator" | true | { Power = 4500, Interval = 1.4, Radius = 3.6, SandMultiplier = 140 } |

### Sandy Crab (`sandy_crab`)

```lua
{
		Id = "sandy_crab",
		Name = "Sandy Crab",
		Rarity = "Common",
		Multiplier = 1.05,
		Dig = { Power = 4, Interval = 4, Radius = 2, SandMultiplier = 1 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 80),
			AccentColor = rgb(255, 220, 180),
			Shape = "Crab",
			Size = 1,
			Glow = false,
		},
	}
```

### Seagull (`seagull`)

```lua
{
		Id = "seagull",
		Name = "Seagull",
		Rarity = "Common",
		Multiplier = 1.08,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 250, 250),
			AccentColor = rgb(255, 190, 40),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Starfish (`starfish`)

```lua
{
		Id = "starfish",
		Name = "Starfish",
		Rarity = "Uncommon",
		Multiplier = 1.12,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 150, 60),
			AccentColor = rgb(255, 230, 120),
			Shape = "Star",
			Size = 1,
			Glow = false,
		},
	}
```

### Baby Turtle (`baby_turtle`)

```lua
{
		Id = "baby_turtle",
		Name = "Baby Turtle",
		Rarity = "Rare",
		Multiplier = 1.2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 200, 90),
			AccentColor = rgb(190, 140, 80),
			Shape = "Turtle",
			Size = 0.9,
			Glow = false,
		},
	}
```

### Golden Crab (`golden_crab`)

```lua
{
		Id = "golden_crab",
		Name = "Golden Crab",
		Rarity = "Legendary",
		Multiplier = 1.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 40),
			AccentColor = rgb(255, 255, 200),
			Shape = "Crab",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Clownfish (`clownfish`)

```lua
{
		Id = "clownfish",
		Name = "Clownfish",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 130, 30),
			AccentColor = rgb(255, 255, 255),
			Shape = "Fish",
			Size = 1,
			Glow = false,
		},
	}
```

### Pufferfish (`pufferfish`)

```lua
{
		Id = "pufferfish",
		Name = "Pufferfish",
		Rarity = "Uncommon",
		Multiplier = 1.22,
		Exclusive = false,
		Look = {
			BodyColor = rgb(250, 220, 100),
			AccentColor = rgb(120, 90, 60),
			Shape = "Blob",
			Size = 1,
			Glow = false,
		},
	}
```

### Octopus (`octopus`)

```lua
{
		Id = "octopus",
		Name = "Octopus",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 90, 170),
			AccentColor = rgb(255, 200, 230),
			Shape = "Squid",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Sea Turtle (`sea_turtle`)

```lua
{
		Id = "sea_turtle",
		Name = "Sea Turtle",
		Rarity = "Epic",
		Multiplier = 1.45,
		Exclusive = false,
		Look = {
			BodyColor = rgb(40, 170, 140),
			AccentColor = rgb(220, 190, 120),
			Shape = "Turtle",
			Size = 1.2,
			Glow = false,
		},
	}
```

### Rainbow Starfish (`rainbow_starfish`)

```lua
{
		Id = "rainbow_starfish",
		Name = "Rainbow Starfish",
		Rarity = "Legendary",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 90, 200),
			AccentColor = rgb(90, 220, 255),
			Shape = "Star",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Pirate Parrot (`parrot`)

```lua
{
		Id = "parrot",
		Name = "Pirate Parrot",
		Rarity = "Common",
		Multiplier = 1.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 40, 40),
			AccentColor = rgb(40, 120, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Pirate Crab (`pirate_crab`)

```lua
{
		Id = "pirate_crab",
		Name = "Pirate Crab",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Dig = { Power = 25, Interval = 3.5, Radius = 2.2, SandMultiplier = 3 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 50, 40),
			AccentColor = rgb(30, 30, 30),
			Shape = "Crab",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Ghost Blob (`ghost_blob`)

```lua
{
		Id = "ghost_blob",
		Name = "Ghost Blob",
		Rarity = "Rare",
		Multiplier = 1.55,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 255, 230),
			AccentColor = rgb(120, 220, 200),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Skeleton Shark (`skeleton_shark`)

```lua
{
		Id = "skeleton_shark",
		Name = "Skeleton Shark",
		Rarity = "Epic",
		Multiplier = 1.75,
		Exclusive = false,
		Look = {
			BodyColor = rgb(240, 235, 220),
			AccentColor = rgb(80, 80, 90),
			Shape = "Fish",
			Size = 1.3,
			Glow = false,
		},
	}
```

### Kraken (`kraken`)

```lua
{
		Id = "kraken",
		Name = "Kraken",
		Rarity = "Legendary",
		Multiplier = 2.3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 40, 160),
			AccentColor = rgb(255, 120, 200),
			Shape = "Squid",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Mole (`mole`)

```lua
{
		Id = "mole",
		Name = "Mole",
		Rarity = "Common",
		Multiplier = 1.5,
		Dig = { Power = 45, Interval = 3, Radius = 2.2, SandMultiplier = 4.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 80, 70),
			AccentColor = rgb(255, 170, 180),
			Shape = "Mole",
			Size = 1,
			Glow = false,
		},
	}
```

### Baby Raptor (`baby_raptor`)

```lua
{
		Id = "baby_raptor",
		Name = "Baby Raptor",
		Rarity = "Uncommon",
		Multiplier = 1.7,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 180, 80),
			AccentColor = rgb(230, 200, 120),
			Shape = "Dino",
			Size = 1,
			Glow = false,
		},
	}
```

### Stegosaurus (`stegosaurus`)

```lua
{
		Id = "stegosaurus",
		Name = "Stegosaurus",
		Rarity = "Rare",
		Multiplier = 1.9,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 150, 200),
			AccentColor = rgb(255, 140, 60),
			Shape = "Dino",
			Size = 1.2,
			Glow = false,
		},
	}
```

### T-Rex (`trex`)

```lua
{
		Id = "trex",
		Name = "T-Rex",
		Rarity = "Epic",
		Multiplier = 2.2,
		Dig = { Power = 80, Interval = 2.8, Radius = 2.4, SandMultiplier = 7.2 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(70, 140, 70),
			AccentColor = rgb(250, 240, 220),
			Shape = "Dino",
			Size = 1.4,
			Glow = false,
		},
	}
```

### Bone Dragon (`bone_dragon`)

```lua
{
		Id = "bone_dragon",
		Name = "Bone Dragon",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(245, 240, 225),
			AccentColor = rgb(120, 255, 180),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Crystal Bat (`crystal_bat`)

```lua
{
		Id = "crystal_bat",
		Name = "Crystal Bat",
		Rarity = "Common",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(220, 170, 255),
			Shape = "Bird",
			Size = 1,
			Glow = false,
		},
	}
```

### Gem Blob (`gem_blob`)

```lua
{
		Id = "gem_blob",
		Name = "Gem Blob",
		Rarity = "Uncommon",
		Multiplier = 2.1,
		Exclusive = false,
		Look = {
			BodyColor = rgb(80, 200, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	}
```

### Crystal Golem (`crystal_golem`)

```lua
{
		Id = "crystal_golem",
		Name = "Crystal Golem",
		Rarity = "Rare",
		Multiplier = 2.5,
		Dig = { Power = 140, Interval = 3, Radius = 2.4, SandMultiplier = 12 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(180, 110, 255),
			AccentColor = rgb(240, 220, 255),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Frost Seal (`frost_seal`)

```lua
{
		Id = "frost_seal",
		Name = "Frost Seal",
		Rarity = "Epic",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 240, 255),
			AccentColor = rgb(80, 160, 255),
			Shape = "Seal",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Diamond Dragon (`diamond_dragon`)

```lua
{
		Id = "diamond_dragon",
		Name = "Diamond Dragon",
		Rarity = "Legendary",
		Multiplier = 4,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 250, 255),
			AccentColor = rgb(150, 120, 255),
			Shape = "Dragon",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Lava Salamander (`lava_salamander`)

```lua
{
		Id = "lava_salamander",
		Name = "Lava Salamander",
		Rarity = "Common",
		Multiplier = 2.5,
		Dig = { Power = 800, Interval = 3, Radius = 2.4, SandMultiplier = 34 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 110, 30),
			AccentColor = rgb(60, 30, 30),
			Shape = "Dino",
			Size = 1,
			Glow = true,
		},
	}
```

### Magma Golem (`magma_golem`)

```lua
{
		Id = "magma_golem",
		Name = "Magma Golem",
		Rarity = "Uncommon",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(100, 65, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Golem",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Fire Bird (`fire_bird`)

```lua
{
		Id = "fire_bird",
		Name = "Fire Bird",
		Rarity = "Rare",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 80, 30),
			AccentColor = rgb(255, 220, 60),
			Shape = "Bird",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Lava Kraken (`lava_kraken`)

```lua
{
		Id = "lava_kraken",
		Name = "Lava Kraken",
		Rarity = "Epic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(200, 40, 20),
			AccentColor = rgb(255, 200, 40),
			Shape = "Squid",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Phoenix (`phoenix`)

```lua
{
		Id = "phoenix",
		Name = "Phoenix",
		Rarity = "Legendary",
		Multiplier = 6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 170, 30),
			AccentColor = rgb(255, 60, 40),
			Shape = "Bird",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Core Dragon (`core_dragon`)

```lua
{
		Id = "core_dragon",
		Name = "Core Dragon",
		Rarity = "Mythic",
		Multiplier = 10,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 90, 20),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Alien Blob (`alien_blob`)

```lua
{
		Id = "alien_blob",
		Name = "Alien Blob",
		Rarity = "Common",
		Multiplier = 3.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(110, 255, 120),
			AccentColor = rgb(40, 120, 60),
			Shape = "Blob",
			Size = 1,
			Glow = true,
		},
	}
```

### Cosmic Turtle (`cosmic_turtle`)

```lua
{
		Id = "cosmic_turtle",
		Name = "Cosmic Turtle",
		Rarity = "Rare",
		Multiplier = 5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(60, 40, 140),
			AccentColor = rgb(150, 220, 255),
			Shape = "Turtle",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Star Golem (`star_golem`)

```lua
{
		Id = "star_golem",
		Name = "Star Golem",
		Rarity = "Epic",
		Multiplier = 7,
		Dig = { Power = 2500, Interval = 2.8, Radius = 2.6, SandMultiplier = 104 },
		Exclusive = false,
		Look = {
			BodyColor = rgb(65, 65, 110),
			AccentColor = rgb(255, 240, 120),
			Shape = "Golem",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Galaxy Dragon (`galaxy_dragon`)

```lua
{
		Id = "galaxy_dragon",
		Name = "Galaxy Dragon",
		Rarity = "Mythic",
		Multiplier = 15,
		Exclusive = false,
		Look = {
			BodyColor = rgb(90, 40, 200),
			AccentColor = rgb(255, 120, 255),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Tide Spirit (`tide_spirit`)

```lua
{
		Id = "tide_spirit",
		Name = "Tide Spirit",
		Rarity = "Rare",
		Multiplier = 1.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 220, 255),
			AccentColor = rgb(255, 255, 255),
			Shape = "Blob",
			Size = 1.1,
			Glow = true,
		},
	}
```

### Rebirth Phoenix (`rebirth_phoenix`)

```lua
{
		Id = "rebirth_phoenix",
		Name = "Rebirth Phoenix",
		Rarity = "Epic",
		Multiplier = 2,
		Exclusive = false,
		Look = {
			BodyColor = rgb(120, 255, 200),
			AccentColor = rgb(255, 255, 140),
			Shape = "Bird",
			Size = 1.3,
			Glow = true,
		},
	}
```

### Sandlantis Guardian (`sandlantis_guardian`)

```lua
{
		Id = "sandlantis_guardian",
		Name = "Sandlantis Guardian",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		Look = {
			BodyColor = rgb(230, 190, 100),
			AccentColor = rgb(60, 200, 200),
			Shape = "Golem",
			Size = 1.5,
			Glow = true,
		},
	}
```

### Golden Seagull (`golden_seagull`)

```lua
{
		Id = "golden_seagull",
		Name = "Golden Seagull",
		Rarity = "Epic",
		Multiplier = 1.8,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 215, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bird",
			Size = 1.2,
			Glow = true,
		},
	}
```

### Golden Turtle (`golden_turtle`)

```lua
{
		Id = "golden_turtle",
		Name = "Golden Turtle",
		Rarity = "Legendary",
		Multiplier = 2.6,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 200, 40),
			AccentColor = rgb(255, 240, 170),
			Shape = "Turtle",
			Size = 1.4,
			Glow = true,
		},
	}
```

### Sun Dragon (`sun_dragon`)

```lua
{
		Id = "sun_dragon",
		Name = "Sun Dragon",
		Rarity = "Mythic",
		Multiplier = 4.5,
		Exclusive = false,
		Look = {
			BodyColor = rgb(255, 180, 30),
			AccentColor = rgb(255, 255, 180),
			Shape = "Dragon",
			Size = 1.6,
			Glow = true,
		},
	}
```

### Sunny Seal (`sunny_seal`)

```lua
{
		Id = "sunny_seal",
		Name = "Sunny Seal",
		Rarity = "Epic",
		Multiplier = 1.5,
		Exclusive = true,
		Look = {
			BodyColor = rgb(250, 250, 255),
			AccentColor = rgb(255, 190, 60),
			Shape = "Seal",
			Size = 1.1,
			Glow = false,
		},
	}
```

### Launch Party Crab (`launch_crab`)

```lua
{
		Id = "launch_crab",
		Name = "Launch Party Crab",
		Rarity = "Rare",
		Multiplier = 1.25,
		Exclusive = true,
		Look = {
			BodyColor = rgb(60, 200, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Crab",
			Size = 1,
			Glow = true,
		},
	}
```

### Toy Sand Truck (`toy_truck`)

```lua
{
		Id = "toy_truck",
		Name = "Toy Sand Truck",
		Rarity = "Common",
		Multiplier = 1.05,
		Exclusive = false,
		VehicleKind = "ToyTruck",
		Dig = { Power = 15, Interval = 3, Radius = 2.2, SandMultiplier = 2.25 },
		Look = {
			BodyColor = rgb(255, 210, 50),
			AccentColor = rgb(240, 70, 70),
			Shape = "Vehicle",
			Size = 0.95,
			Glow = false,
		},
	}
```

### Little Dump Truck (`dump_truck`)

```lua
{
		Id = "dump_truck",
		Name = "Little Dump Truck",
		Rarity = "Uncommon",
		Multiplier = 1.08,
		Exclusive = false,
		VehicleKind = "DumpTruck",
		Dig = { Power = 25, Interval = 2.8, Radius = 2.2, SandMultiplier = 3.6 },
		Look = {
			BodyColor = rgb(255, 150, 40),
			AccentColor = rgb(70, 80, 95),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Mini Excavator (`mini_excavator`)

```lua
{
		Id = "mini_excavator",
		Name = "Mini Excavator",
		Rarity = "Rare",
		Multiplier = 1.12,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 45, Interval = 2.6, Radius = 2.4, SandMultiplier = 6.4 },
		Look = {
			BodyColor = rgb(255, 200, 30),
			AccentColor = rgb(55, 55, 65),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Skid Steer (`skid_steer`)

```lua
{
		Id = "skid_steer",
		Name = "Skid Steer",
		Rarity = "Common",
		Multiplier = 1.15,
		Exclusive = false,
		VehicleKind = "SkidSteer",
		Dig = { Power = 80, Interval = 2.4, Radius = 2.4, SandMultiplier = 6.2 },
		Look = {
			BodyColor = rgb(80, 200, 90),
			AccentColor = rgb(45, 50, 60),
			Shape = "Vehicle",
			Size = 0.85,
			Glow = false,
		},
	}
```

### Bulldozer (`bulldozer`)

```lua
{
		Id = "bulldozer",
		Name = "Bulldozer",
		Rarity = "Uncommon",
		Multiplier = 1.2,
		Exclusive = false,
		VehicleKind = "Bulldozer",
		Dig = { Power = 140, Interval = 2.3, Radius = 2.6, SandMultiplier = 10.8 },
		Look = {
			BodyColor = rgb(255, 185, 20),
			AccentColor = rgb(60, 60, 70),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Backhoe Loader (`backhoe`)

```lua
{
		Id = "backhoe",
		Name = "Backhoe Loader",
		Rarity = "Rare",
		Multiplier = 1.3,
		Exclusive = false,
		VehicleKind = "Backhoe",
		Dig = { Power = 250, Interval = 2.2, Radius = 2.6, SandMultiplier = 18.5 },
		Look = {
			BodyColor = rgb(90, 170, 255),
			AccentColor = rgb(40, 60, 110),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Drill Rig (`drill_rig`)

```lua
{
		Id = "drill_rig",
		Name = "Drill Rig",
		Rarity = "Common",
		Multiplier = 1.4,
		Exclusive = false,
		VehicleKind = "DrillRig",
		Dig = { Power = 450, Interval = 2, Radius = 2.8, SandMultiplier = 18 },
		Look = {
			BodyColor = rgb(230, 60, 60),
			AccentColor = rgb(200, 205, 215),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Mining Cart Drill (`mining_drill`)

```lua
{
		Id = "mining_drill",
		Name = "Mining Cart Drill",
		Rarity = "Uncommon",
		Multiplier = 1.55,
		Exclusive = false,
		VehicleKind = "MiningDrill",
		Dig = { Power = 800, Interval = 1.9, Radius = 2.8, SandMultiplier = 32 },
		Look = {
			BodyColor = rgb(150, 100, 60),
			AccentColor = rgb(255, 120, 30),
			Shape = "Vehicle",
			Size = 0.8,
			Glow = false,
		},
	}
```

### Tunnel Borer (`tunnel_borer`)

```lua
{
		Id = "tunnel_borer",
		Name = "Tunnel Borer",
		Rarity = "Rare",
		Multiplier = 1.75,
		Exclusive = false,
		VehicleKind = "TunnelBorer",
		Dig = { Power = 1400, Interval = 1.8, Radius = 2.8, SandMultiplier = 56 },
		Look = {
			BodyColor = rgb(120, 70, 200),
			AccentColor = rgb(60, 40, 90),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Mole Machine (`mole_machine`)

```lua
{
		Id = "mole_machine",
		Name = "Mole Machine",
		Rarity = "Common",
		Multiplier = 2,
		Exclusive = false,
		VehicleKind = "Mole",
		Dig = { Power = 2500, Interval = 1.7, Radius = 2.8, SandMultiplier = 63 },
		Look = {
			BodyColor = rgb(140, 110, 95),
			AccentColor = rgb(90, 255, 140),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Lava Drill (`lava_drill`)

```lua
{
		Id = "lava_drill",
		Name = "Lava Drill",
		Rarity = "Rare",
		Multiplier = 2.4,
		Exclusive = false,
		VehicleKind = "LavaDrill",
		Dig = { Power = 2500, Interval = 1.6, Radius = 2.8, SandMultiplier = 77 },
		Look = {
			BodyColor = rgb(50, 35, 35),
			AccentColor = rgb(255, 100, 20),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Core Driller (`core_driller`)

```lua
{
		Id = "core_driller",
		Name = "Core Driller",
		Rarity = "Legendary",
		Multiplier = 3,
		Exclusive = false,
		VehicleKind = "CoreDriller",
		Dig = { Power = 4500, Interval = 1.5, Radius = 3.2, SandMultiplier = 140 },
		Look = {
			BodyColor = rgb(255, 210, 60),
			AccentColor = rgb(255, 120, 40),
			Shape = "Vehicle",
			Size = 0.75,
			Glow = true,
		},
	}
```

### Mega Excavator (`mega_excavator`)

```lua
{
		Id = "mega_excavator",
		Name = "Mega Excavator",
		Rarity = "Mythic",
		Multiplier = 4,
		Exclusive = false,
		VehicleKind = "Excavator",
		Dig = { Power = 4500, Interval = 1.4, Radius = 3.6, SandMultiplier = 140 },
		Rideable = true,
		Look = {
			BodyColor = rgb(255, 190, 20),
			AccentColor = rgb(255, 90, 160),
			Shape = "Vehicle",
			Size = 1.25,
			Glow = true,
		},
	}
```
## Quests — 12 records

| ID | Name | Kind | Target | Reset | Reward |
|---|---|---|---|---|---|
| daily_dig_100 | Busy Beaver | "DigTimes" | 100 | "Daily" | { ScaledCoins = 60 } |
| daily_dig_1000 | Dig Machine | "DigTimes" | 1000 | "Daily" | { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 } |
| daily_sell_10 | Sand Salesman | "SellTimes" | 10 | "Daily" | { ScaledCoins = 120 } |
| daily_treasure_10 | Treasure Hunter | "FindTreasures" | 10 | "Daily" | { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 } |
| daily_rare_1 | Lucky Find | "FindRarity" | 1 | "Daily" | { ScaledCoins = 180 } |
| daily_hatch_5 | Egg-cellent | "HatchEggs" | 5 | "Daily" | { ScaledCoins = 150 } |
| daily_play_20 | Beach Day | "PlayMinutes" | 20 | "Daily" | { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 } |
| reach_pirate_cove | Yo Ho Ho! | "ReachDepth" | 110 | "Once" | { Coins = 1500 } |
| reach_fossil_bed | Jurassic Beach | "ReachDepth" | 200 | "Once" | { Coins = 25000, Egg = "beach_egg", EggCount = 3 } |
| reach_crystal_caverns | Shiny! | "ReachDepth" | 330 | "Once" | { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 } |
| first_rebirth | Born Again Digger | "Rebirth" | 1 | "Once" | { RebirthTokens = 2 } |
| reach_the_core | Journey to the Center | "ReachDepth" | 885 | "Once" | { RebirthTokens = 10, ScaledCoins = 1800 } |

### Busy Beaver (`daily_dig_100`)

```lua
{
		Id = "daily_dig_100",
		Name = "Busy Beaver",
		Description = "Dig 100 times",
		Kind = "DigTimes",
		Target = 100,
		Reset = "Daily",
		Reward = { ScaledCoins = 60 },
	}
```

### Dig Machine (`daily_dig_1000`)

```lua
{
		Id = "daily_dig_1000",
		Name = "Dig Machine",
		Description = "Dig 1,000 times",
		Kind = "DigTimes",
		Target = 1000,
		Reset = "Daily",
		Reward = { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 },
	}
```

### Sand Salesman (`daily_sell_10`)

```lua
{
		Id = "daily_sell_10",
		Name = "Sand Salesman",
		Description = "Sell your sand 10 times",
		Kind = "SellTimes",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120 },
	}
```

### Treasure Hunter (`daily_treasure_10`)

```lua
{
		Id = "daily_treasure_10",
		Name = "Treasure Hunter",
		Description = "Find 10 treasures",
		Kind = "FindTreasures",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 },
	}
```

### Lucky Find (`daily_rare_1`)

```lua
{
		Id = "daily_rare_1",
		Name = "Lucky Find",
		Description = "Find a Rare (or better) treasure",
		Kind = "FindRarity",
		Target = 1,
		Rarity = "Rare",
		Reset = "Daily",
		Reward = { ScaledCoins = 180 },
	}
```

### Egg-cellent (`daily_hatch_5`)

```lua
{
		Id = "daily_hatch_5",
		Name = "Egg-cellent",
		Description = "Hatch 5 eggs",
		Kind = "HatchEggs",
		Target = 5,
		Reset = "Daily",
		Reward = { ScaledCoins = 150 },
	}
```

### Beach Day (`daily_play_20`)

```lua
{
		Id = "daily_play_20",
		Name = "Beach Day",
		Description = "Play for 20 minutes",
		Kind = "PlayMinutes",
		Target = 20,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 },
	}
```

### Yo Ho Ho! (`reach_pirate_cove`)

```lua
{
		Id = "reach_pirate_cove",
		Name = "Yo Ho Ho!",
		Description = "Reach the Pirate Cove (110m)",
		Kind = "ReachDepth",
		Target = 110,
		Reset = "Once",
		Reward = { Coins = 1500 },
	}
```

### Jurassic Beach (`reach_fossil_bed`)

```lua
{
		Id = "reach_fossil_bed",
		Name = "Jurassic Beach",
		Description = "Reach the Fossil Bed (200m)",
		Kind = "ReachDepth",
		Target = 200,
		Reset = "Once",
		Reward = { Coins = 25000, Egg = "beach_egg", EggCount = 3 },
	}
```

### Shiny! (`reach_crystal_caverns`)

```lua
{
		Id = "reach_crystal_caverns",
		Name = "Shiny!",
		Description = "Reach the Crystal Caverns (330m)",
		Kind = "ReachDepth",
		Target = 330,
		Reset = "Once",
		Reward = { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 },
	}
```

### Born Again Digger (`first_rebirth`)

```lua
{
		Id = "first_rebirth",
		Name = "Born Again Digger",
		Description = "Rebirth for the first time",
		Kind = "Rebirth",
		Target = 1,
		Reset = "Once",
		Reward = { RebirthTokens = 2 },
	}
```

### Journey to the Center (`reach_the_core`)

```lua
{
		Id = "reach_the_core",
		Name = "Journey to the Center",
		Description = "Reach THE CORE (885m)",
		Kind = "ReachDepth",
		Target = 885,
		Reset = "Once",
		Reward = { RebirthTokens = 10, ScaledCoins = 1800 },
	}
```
## Rarities — 7 records

| ID | Name | Price | Description | Reward |
|---|---|---|---|---|
| Common | Common | — | — | — |
| Uncommon | Uncommon | — | — | — |
| Rare | Rare | — | — | — |
| Epic | Epic | — | — | — |
| Legendary | Legendary | — | — | — |
| Mythic | Mythic | — | — | — |
| Relic | Relic | — | — | — |

### Common (`Common`)

```lua
{
		Name = "Common",
		Order = 1,
		Color = rgb(200, 205, 215),
		Gradient = { rgb(230, 232, 238), rgb(170, 176, 190) },
		Announce = false,
	}
```

### Uncommon (`Uncommon`)

```lua
{
		Name = "Uncommon",
		Order = 2,
		Color = rgb(90, 220, 100),
		Gradient = { rgb(150, 255, 150), rgb(40, 180, 80) },
		Announce = false,
	}
```

### Rare (`Rare`)

```lua
{
		Name = "Rare",
		Order = 3,
		Color = rgb(60, 160, 255),
		Gradient = { rgb(120, 210, 255), rgb(30, 100, 240) },
		Announce = false,
	}
```

### Epic (`Epic`)

```lua
{
		Name = "Epic",
		Order = 4,
		Color = rgb(180, 90, 255),
		Gradient = { rgb(220, 150, 255), rgb(130, 50, 230) },
		Announce = false,
	}
```

### Legendary (`Legendary`)

```lua
{
		Name = "Legendary",
		Order = 5,
		Color = rgb(255, 190, 30),
		Gradient = { rgb(255, 235, 100), rgb(255, 130, 20) },
		Announce = true,
	}
```

### Mythic (`Mythic`)

```lua
{
		Name = "Mythic",
		Order = 6,
		Color = rgb(255, 70, 140),
		Gradient = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(90, 220, 255), rgb(200, 90, 255) },
		Announce = true,
	}
```

### Relic (`Relic`)

```lua
{
		Name = "Relic",
		Order = 7,
		Color = rgb(120, 255, 230),
		Gradient = { rgb(255, 255, 255), rgb(120, 255, 230), rgb(255, 120, 230), rgb(255, 230, 120) },
		Announce = true,
	}
```
## RebirthPerks — 8 records

| ID | Name | Costs | Effects |
|---|---|---|---|
| SellAnywhere | Sell Anywhere | { 5 } | — |
| HeadStart | Head Start | { 1, 2, 3, 5, 8 } | — |
| GoldenTouch | Golden Touch | { 1, 2, 3, 4, 5 } | — |
| KeepBackpack | Keep Backpack | { 1, 3, 6 } | — |
| DeepPockets | Deep Pockets | { 1, 1, 2, 3, 4 } | — |
| LuckyDigger | Lucky Digger | { 1, 2, 2, 3, 4 } | — |
| LongNap | Long Nap | { 1, 2, 3, 4 } | — |
| PetDen | Pet Den | { 3, 6 } | — |

### Sell Anywhere (`SellAnywhere`)

```lua
{
		Id = "SellAnywhere",
		Name = "Sell Anywhere",
		Icon = "sell|💸",
		Description = "Sell from anywhere with one tap, like the game pass.",
		Costs = { 5 },
		Levels = { { Unlocked = true } },
		Order = 1,
	}
```

### Head Start (`HeadStart`)

```lua
{
		Id = "HeadStart",
		Name = "Head Start",
		Icon = "shovel|⛏️",
		Description = "Start every rebirth with a better shovel and some coins.",
		Costs = { 1, 2, 3, 5, 8 },
		Levels = {
			{ ShovelIndex = 4, Coins = 500 }, -- Lifeguard Shovel
			{ ShovelIndex = 5, Coins = 5_000 }, -- Pirate Shovel
			{ ShovelIndex = 6, Coins = 25_000 }, -- Bone Claw
			{ ShovelIndex = 7, Coins = 100_000 }, -- Steel Pickaxe
			{ ShovelIndex = 8, Coins = 400_000 }, -- Crystal Spade
		},
		Order = 2,
	}
```

### Golden Touch (`GoldenTouch`)

```lua
{
		Id = "GoldenTouch",
		Name = "Golden Touch",
		Icon = "boost_coins|💰",
		Description = "More coins every time you sell.",
		Costs = { 1, 2, 3, 4, 5 },
		Levels = { { Coin = 1.1 }, { Coin = 1.2 }, { Coin = 1.3 }, { Coin = 1.4 }, { Coin = 1.5 } },
		Order = 3,
	}
```

### Keep Backpack (`KeepBackpack`)

```lua
{
		Id = "KeepBackpack",
		Name = "Keep Backpack",
		Icon = "backpack|🎒",
		Description = "Keep your backpack when you rebirth.",
		Costs = { 1, 3, 6 },
		Levels = {
			{ KeepIndex = 5 }, -- up to Treasure Sack
			{ KeepIndex = 8 }, -- up to Wheelbarrow
			{ KeepIndex = 99 }, -- any backpack
		},
		Order = 4,
	}
```

### Deep Pockets (`DeepPockets`)

```lua
{
		Id = "DeepPockets",
		Name = "Deep Pockets",
		Icon = "sand|⏳",
		Description = "Your backpack holds more sand.",
		Costs = { 1, 1, 2, 3, 4 },
		Levels = {
			{ Capacity = 1.1 },
			{ Capacity = 1.2 },
			{ Capacity = 1.3 },
			{ Capacity = 1.4 },
			{ Capacity = 1.5 },
		},
		Order = 5,
	}
```

### Lucky Digger (`LuckyDigger`)

```lua
{
		Id = "LuckyDigger",
		Name = "Lucky Digger",
		Icon = "boost_luck|🍀",
		Description = "Find treasure more often while digging.",
		Costs = { 1, 2, 2, 3, 4 },
		Levels = {
			{ TreasureChance = 1.1 },
			{ TreasureChance = 1.2 },
			{ TreasureChance = 1.3 },
			{ TreasureChance = 1.4 },
			{ TreasureChance = 1.5 },
		},
		Order = 6,
	}
```

### Long Nap (`LongNap`)

```lua
{
		Id = "LongNap",
		Name = "Long Nap",
		Icon = "hourglass|⏳",
		Description = "Your pets dig longer and harder while you are away.",
		Costs = { 1, 2, 3, 4 },
		Levels = {
			{ OfflineHours = 1, OfflineEfficiency = 0.1 },
			{ OfflineHours = 2, OfflineEfficiency = 0.2 },
			{ OfflineHours = 3, OfflineEfficiency = 0.3 },
			{ OfflineHours = 4, OfflineEfficiency = 0.4 },
		},
		Order = 7,
	}
```

### Pet Den (`PetDen`)

```lua
{
		Id = "PetDen",
		Name = "Pet Den",
		Icon = "pets|🐾",
		Description = "+1 pet slot.",
		Costs = { 3, 6 },
		Levels = { { PetSlots = 1 }, { PetSlots = 2 } },
		Order = 8,
	}
```
## Shades — 7 records

| ID | Name | Price | Radius | Cooling |
|---|---|---|---|---|
| beach_umbrella | Beach Umbrella | 120 | 6 | 1 |
| striped_umbrella | Striped Umbrella | 1200 | 8 | 1.4 |
| palm_tarp | Palm Tarp | 12000 | 10 | 1.8 |
| party_canopy | Party Canopy | 100000 | 12 | 2.3 |
| tiki_cabana | Tiki Cabana | 750000 | 14 | 2.8 |
| luxury_tent | Luxury Beach Tent | 6000000 | 17 | 3.5 |
| royal_pavilion | Royal Sand Pavilion | 80000000 | 21 | 4.5 |

### Beach Umbrella (`beach_umbrella`)

```lua
{
		Id = "beach_umbrella",
		Name = "Beach Umbrella",
		Price = 120,
		Radius = 6,
		Cooling = 1,
		Height = 7.5,
		Description = "A trusty umbrella. Shade for you and a friend.",
		Look = { Style = "Umbrella", Color = rgb(255, 80, 90), Accent = rgb(255, 255, 255) },
	}
```

### Striped Umbrella (`striped_umbrella`)

```lua
{
		Id = "striped_umbrella",
		Name = "Striped Umbrella",
		Price = 1200,
		Radius = 8,
		Cooling = 1.4,
		Height = 8,
		Description = "Extra-wide rainbow stripes. Cools faster!",
		Look = { Style = "Striped", Color = rgb(40, 170, 255), Accent = rgb(255, 225, 60) },
	}
```

### Palm Tarp (`palm_tarp`)

```lua
{
		Id = "palm_tarp",
		Name = "Palm Tarp",
		Price = 12000,
		Radius = 10,
		Cooling = 1.8,
		Height = 8.5,
		Description = "A big tarp tied between palm-wood poles. Room for the squad.",
		Look = { Style = "Tarp", Color = rgb(255, 150, 40), Accent = rgb(176, 120, 72) },
	}
```

### Party Canopy (`party_canopy`)

```lua
{
		Id = "party_canopy",
		Name = "Party Canopy",
		Price = 100000,
		Radius = 12,
		Cooling = 2.3,
		Height = 9,
		Description = "A pop-up party tent with bunting. Very cool. Literally.",
		Look = { Style = "Canopy", Color = rgb(90, 210, 120), Accent = rgb(255, 255, 255) },
	}
```

### Tiki Cabana (`tiki_cabana`)

```lua
{
		Id = "tiki_cabana",
		Name = "Tiki Cabana",
		Price = 750000,
		Radius = 14,
		Cooling = 2.8,
		Height = 9,
		Description = "A thatched tiki hut with curtains. Island vibes.",
		Look = { Style = "Cabana", Color = rgb(225, 190, 110), Accent = rgb(255, 120, 150) },
	}
```

### Luxury Beach Tent (`luxury_tent`)

```lua
{
		Id = "luxury_tent",
		Name = "Luxury Beach Tent",
		Price = 6000000,
		RebirthsRequired = 1,
		Radius = 17,
		Cooling = 3.5,
		Height = 9.5,
		Description = "Silk walls and gold poles. Requires 1 Rebirth.",
		Look = { Style = "Tent", Color = rgb(250, 245, 235), Accent = rgb(255, 200, 40) },
	}
```

### Royal Sand Pavilion (`royal_pavilion`)

```lua
{
		Id = "royal_pavilion",
		Name = "Royal Sand Pavilion",
		Price = 80000000,
		RebirthsRequired = 3,
		Radius = 21,
		Cooling = 4.5,
		Height = 10,
		Description = "Fit for the King of Sandlantis. Shade for the whole beach! Requires 3 Rebirths.",
		Look = { Style = "Pavilion", Color = rgb(150, 90, 255), Accent = rgb(255, 205, 40) },
	}
```
## Shovels — 14 records

| ID | Name | Price | Power | Cooldown | Radius | SandMultiplier | RebirthsRequired |
|---|---|---|---|---|---|---|---|
| toy_shovel | Hand Spade | 0 | 2 | 0.5 | 2 | 1 | 0 |
| garden_trowel | Garden Trowel | 30 | 4 | 0.46 | 2.2 | 1.5 | 0 |
| metal_spade | Metal Spade | 150 | 8 | 0.43 | 2.5 | 2 | 0 |
| lifeguard_shovel | Lifeguard Shovel | 600 | 15 | 0.4 | 2.8 | 3 | 0 |
| pirate_shovel | Pirate Shovel | 2500 | 25 | 0.37 | 3.2 | 4 | 0 |
| bone_claw | Bone Claw | 9000 | 45 | 0.34 | 3.5 | 6 | 0 |
| steel_pickaxe | Steel Pickaxe | 35000 | 80 | 0.31 | 3.8 | 8 | 0 |
| crystal_spade | Crystal Spade | 140000 | 140 | 0.28 | 4.4 | 11 | 0 |
| frostbite_pick | Frostbite Pick | 600000 | 250 | 0.25 | 5 | 15 | 0 |
| ancient_trident | Ancient Trident | 2500000 | 450 | 0.22 | 5.5 | 20 | 1 |
| magma_pick | Magma Pick | 12000000 | 800 | 0.2 | 6 | 28 | 2 |
| obsidian_drill | Obsidian Drill | 60000000 | 1400 | 0.17 | 6.6 | 38 | 4 |
| plasma_drill | Plasma Drill | 350000000 | 2500 | 0.14 | 7.2 | 52 | 6 |
| core_breaker | Core Breaker | 2500000000 | 4500 | 0.12 | 8 | 75 | 10 |

### Hand Spade (`toy_shovel`)

```lua
{
		Id = "toy_shovel", -- id kept from v1 ("Plastic Toy Shovel") so saves keep working
		Name = "Hand Spade",
		Price = 0,
		Power = 2,
		Cooldown = 0.5,
		Radius = 2,
		SandMultiplier = 1,
		RebirthsRequired = 0,
		Description = "A little plastic beach spade. Everyone starts somewhere! Digs Dry and Wet Sand.",
		Look = {
			HeadColor = rgb(255, 70, 70),
			HandleColor = rgb(255, 210, 50),
			HeadShape = "Scoop",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
			Size = "Hand",
		},
	}
```

### Garden Trowel (`garden_trowel`)

```lua
{
		Id = "garden_trowel",
		Name = "Garden Trowel",
		Price = 30,
		Power = 4,
		Cooldown = 0.46,
		Radius = 2.2,
		SandMultiplier = 1.5,
		RebirthsRequired = 0,
		Description = "Borrowed from Grandma's garden. Breaks into the Shell Bed!",
		Look = {
			HeadColor = rgb(190, 195, 205),
			HandleColor = rgb(70, 200, 90),
			HeadShape = "Trowel",
			Material = Enum.Material.Metal,
			Glow = false,
			Size = "Hand",
		},
	}
```

### Metal Spade (`metal_spade`)

```lua
{
		Id = "metal_spade",
		Name = "Metal Spade",
		Price = 150,
		Power = 8,
		Cooldown = 0.43,
		Radius = 2.5,
		SandMultiplier = 2,
		RebirthsRequired = 0,
		Description = "A real grown-up shovel. Cuts through sticky Tidal Clay.",
		Look = {
			HeadColor = rgb(170, 175, 185),
			HandleColor = rgb(140, 95, 55),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Lifeguard Shovel (`lifeguard_shovel`)

```lua
{
		Id = "lifeguard_shovel",
		Name = "Lifeguard Shovel",
		Price = 600,
		Power = 15,
		Cooldown = 0.4,
		Radius = 2.8,
		SandMultiplier = 3,
		RebirthsRequired = 0,
		Description = "Red, white and ready for rescue digs. Reaches Pirate Cove.",
		Look = {
			HeadColor = rgb(235, 40, 40),
			HandleColor = rgb(255, 255, 255),
			HeadShape = "Spade",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Pirate Shovel (`pirate_shovel`)

```lua
{
		Id = "pirate_shovel",
		Name = "Pirate Shovel",
		Price = 2500,
		Power = 25,
		Cooldown = 0.37,
		Radius = 3.2,
		SandMultiplier = 4,
		RebirthsRequired = 0,
		Description = "Captain Sandbeard's own. Smashes through shipwreck planks.",
		Look = {
			HeadColor = rgb(255, 200, 40),
			HandleColor = rgb(90, 55, 30),
			HeadShape = "Spade",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Bone Claw (`bone_claw`)

```lua
{
		Id = "bone_claw",
		Name = "Bone Claw",
		Price = 9000,
		Power = 45,
		Cooldown = 0.34,
		Radius = 3.5,
		SandMultiplier = 6,
		RebirthsRequired = 0,
		Description = "Made from a raptor claw. Perfect for fossil hunting.",
		Look = {
			HeadColor = rgb(245, 238, 215),
			HandleColor = rgb(160, 120, 80),
			HeadShape = "Claw",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	}
```

### Steel Pickaxe (`steel_pickaxe`)

```lua
{
		Id = "steel_pickaxe",
		Name = "Steel Pickaxe",
		Price = 35000,
		Power = 80,
		Cooldown = 0.31,
		Radius = 3.8,
		SandMultiplier = 8,
		RebirthsRequired = 0,
		Description = "Miner-grade steel. Cracks Bedrock like a cookie.",
		Look = {
			HeadColor = rgb(165, 180, 195),
			HandleColor = rgb(60, 60, 70),
			HeadShape = "Pick",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	}
```

### Crystal Spade (`crystal_spade`)

```lua
{
		Id = "crystal_spade",
		Name = "Crystal Spade",
		Price = 140000,
		Power = 140,
		Cooldown = 0.28,
		Radius = 4.4,
		SandMultiplier = 11,
		RebirthsRequired = 0,
		Description = "Carved from a single giant amethyst. Opens the Crystal Caverns.",
		Look = {
			HeadColor = rgb(180, 110, 255),
			HandleColor = rgb(240, 220, 255),
			HeadShape = "Spade",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	}
```

### Frostbite Pick (`frostbite_pick`)

```lua
{
		Id = "frostbite_pick",
		Name = "Frostbite Pick",
		Price = 600000,
		Power = 250,
		Cooldown = 0.25,
		Radius = 5,
		SandMultiplier = 15,
		RebirthsRequired = 0,
		Description = "So cold it freezes the ice before it breaks it.",
		Look = {
			HeadColor = rgb(150, 230, 255),
			HandleColor = rgb(40, 90, 160),
			HeadShape = "Pick",
			Material = Enum.Material.Ice,
			Glow = true,
		},
	}
```

### Ancient Trident (`ancient_trident`)

```lua
{
		Id = "ancient_trident",
		Name = "Ancient Trident",
		Price = 2500000,
		Power = 450,
		Cooldown = 0.22,
		Radius = 5.5,
		SandMultiplier = 20,
		RebirthsRequired = 1,
		Description = "The royal digging fork of Sandlantis. Requires 1 Rebirth.",
		Look = {
			HeadColor = rgb(255, 205, 60),
			HandleColor = rgb(30, 160, 170),
			HeadShape = "Trident",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	}
```

### Magma Pick (`magma_pick`)

```lua
{
		Id = "magma_pick",
		Name = "Magma Pick",
		Price = 12000000,
		Power = 800,
		Cooldown = 0.2,
		Radius = 6,
		SandMultiplier = 28,
		RebirthsRequired = 2,
		Description = "Forged in lava, cooled in a dragon's sneeze. Requires 2 Rebirths.",
		Look = {
			HeadColor = rgb(255, 90, 20),
			HandleColor = rgb(50, 30, 30),
			HeadShape = "Pick",
			Material = Enum.Material.CrackedLava,
			Glow = true,
		},
	}
```

### Obsidian Drill (`obsidian_drill`)

```lua
{
		Id = "obsidian_drill",
		Name = "Obsidian Drill",
		Price = 60000000,
		Power = 1400,
		Cooldown = 0.17,
		Radius = 6.6,
		SandMultiplier = 38,
		RebirthsRequired = 4,
		Description = "A spinning drill of black volcanic glass. Requires 4 Rebirths.",
		Look = {
			HeadColor = rgb(60, 40, 90),
			HandleColor = rgb(180, 70, 255),
			HeadShape = "Drill",
			Material = Enum.Material.Glass,
			Glow = true,
		},
	}
```

### Plasma Drill (`plasma_drill`)

```lua
{
		Id = "plasma_drill",
		Name = "Plasma Drill",
		Price = 350000000,
		Power = 2500,
		Cooldown = 0.14,
		Radius = 7.2,
		SandMultiplier = 52,
		RebirthsRequired = 6,
		Description = "Alien tech that melts through anything. Requires 6 Rebirths.",
		Look = {
			HeadColor = rgb(90, 255, 140),
			HandleColor = rgb(200, 210, 220),
			HeadShape = "Drill",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```

### Core Breaker (`core_breaker`)

```lua
{
		Id = "core_breaker",
		Name = "Core Breaker",
		Price = 2500000000,
		Power = 4500,
		Cooldown = 0.12,
		Radius = 8,
		SandMultiplier = 75,
		RebirthsRequired = 10,
		Description = "The legendary shovel that can touch the Core. Requires 10 Rebirths.",
		Look = {
			HeadColor = rgb(255, 215, 70),
			HandleColor = rgb(255, 120, 40),
			HeadShape = "Claw",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	}
```
## Titles — 15 records

| ID | Name | LayerId | Title |
|---|---|---|---|
| dry_sand | Sandcastle Rookie | — | — |
| wet_sand | Bucket Brigade | — | — |
| shell_bed | Shell Seeker | — | — |
| tidal_clay | Clay Crawler | — | — |
| pirate_cove | Pirate Plunderer | — | — |
| shipwreck | Wreck Diver | — | — |
| fossil_bed | Fossil Hunter | — | — |
| bedrock | Rock Breaker | — | — |
| crystal_caverns | Crystal Miner | — | — |
| frozen_abyss | Ice Tunneler | — | — |
| ancient_ruins | Ruin Raider | — | — |
| magma_chamber | Magma Diver | — | — |
| obsidian_depths | Obsidian Delver | — | — |
| alien_hive | Hive Invader | — | — |
| the_core | Core Breaker | — | — |

### Sandcastle Rookie (`dry_sand`)

```lua
{ LayerId = "dry_sand", Title = "Sandcastle Rookie" }
```

### Bucket Brigade (`wet_sand`)

```lua
{ LayerId = "wet_sand", Title = "Bucket Brigade" }
```

### Shell Seeker (`shell_bed`)

```lua
{ LayerId = "shell_bed", Title = "Shell Seeker" }
```

### Clay Crawler (`tidal_clay`)

```lua
{ LayerId = "tidal_clay", Title = "Clay Crawler", Color = rgb(214, 160, 126) }
```

### Pirate Plunderer (`pirate_cove`)

```lua
{ LayerId = "pirate_cove", Title = "Pirate Plunderer", Color = rgb(222, 168, 110) }
```

### Wreck Diver (`shipwreck`)

```lua
{ LayerId = "shipwreck", Title = "Wreck Diver", Color = rgb(214, 156, 104) }
```

### Fossil Hunter (`fossil_bed`)

```lua
{ LayerId = "fossil_bed", Title = "Fossil Hunter" }
```

### Rock Breaker (`bedrock`)

```lua
{ LayerId = "bedrock", Title = "Rock Breaker", Color = rgb(184, 188, 204) }
```

### Crystal Miner (`crystal_caverns`)

```lua
{ LayerId = "crystal_caverns", Title = "Crystal Miner" }
```

### Ice Tunneler (`frozen_abyss`)

```lua
{ LayerId = "frozen_abyss", Title = "Ice Tunneler" }
```

### Ruin Raider (`ancient_ruins`)

```lua
{ LayerId = "ancient_ruins", Title = "Ruin Raider" }
```

### Magma Diver (`magma_chamber`)

```lua
{ LayerId = "magma_chamber", Title = "Magma Diver" }
```

### Obsidian Delver (`obsidian_depths`)

```lua
{ LayerId = "obsidian_depths", Title = "Obsidian Delver", Color = rgb(170, 130, 240) }
```

### Hive Invader (`alien_hive`)

```lua
{ LayerId = "alien_hive", Title = "Hive Invader" }
```

### Core Breaker (`the_core`)

```lua
{ LayerId = "the_core", Title = "Core Breaker" }
```
## Treasures — 53 records

| ID | Name | Layer | Rarity | SellValue | ScaledValue |
|---|---|---|---|---|---|
| bottle_cap | Bottle Cap | 1 | "Common" | 8 | — |
| lost_flip_flop | Lost Flip-Flop | 1 | "Uncommon" | 20 | — |
| cool_sunglasses | Cool Sunglasses | 1 | "Rare" | 60 | — |
| seashell | Seashell | 2 | "Common" | 16 | — |
| sand_dollar | Sand Dollar | 2 | "Uncommon" | 40 | — |
| message_in_a_bottle | Message in a Bottle | 2 | "Rare" | 120 | — |
| conch_shell | Conch Shell | 3 | "Common" | 50 | — |
| glowing_pearl | Glowing Pearl | 3 | "Uncommon" | 120 | — |
| giant_clam | Giant Clam | 3 | "Rare" | 360 | — |
| rusty_anchor | Rusty Anchor | 4 | "Common" | 130 | — |
| pocket_watch | Old Pocket Watch | 4 | "Uncommon" | 320 | — |
| mermaid_comb | Mermaid's Comb | 4 | "Rare" | 960 | — |
| gold_doubloon | Gold Doubloon | 5 | "Common" | 360 | — |
| pirate_hook | Pirate Hook | 5 | "Uncommon" | 900 | — |
| treasure_map | Treasure Map | 5 | "Rare" | 2700 | — |
| pirate_chest | Pirate Chest | 5 | "Legendary" | 36000 | — |
| ships_wheel | Ship's Wheel | 6 | "Common" | 960 | — |
| captains_spyglass | Captain's Spyglass | 6 | "Uncommon" | 2400 | — |
| cursed_skull | Cursed Skull | 6 | "Epic" | 24000 | — |
| trilobite | Trilobite | 7 | "Common" | 2900 | — |
| ammonite | Ammonite | 7 | "Uncommon" | 7200 | — |
| trex_tooth | T-Rex Tooth | 7 | "Rare" | 22000 | — |
| dino_skull | Dino Skull | 7 | "Legendary" | 290000 | — |
| geode | Geode | 8 | "Common" | 7700 | — |
| iron_nugget | Iron Nugget | 8 | "Uncommon" | 19000 | — |
| ancient_arrowhead | Ancient Arrowhead | 8 | "Rare" | 58000 | — |
| amethyst | Amethyst | 9 | "Common" | 22000 | — |
| sapphire | Sapphire | 9 | "Uncommon" | 55000 | — |
| glow_crystal | Glow Crystal | 9 | "Rare" | 160000 | — |
| rainbow_diamond | Rainbow Diamond | 9 | "Legendary" | 2200000 | — |
| frozen_fish | Frozen Fish | 10 | "Common" | 66000 | — |
| mammoth_tusk | Mammoth Tusk | 10 | "Uncommon" | 160000 | — |
| ice_crown | Ice Crown | 10 | "Epic" | 1600000 | — |
| stone_tablet | Stone Tablet | 11 | "Common" | 190000 | — |
| golden_idol | Golden Idol | 11 | "Uncommon" | 480000 | — |
| sun_mask | Sun Mask | 11 | "Rare" | 1400000 | — |
| atlantis_crown | Crown of Sandlantis | 11 | "Legendary" | 19000000 | — |
| obsidian_shard | Obsidian Shard | 12 | "Common" | 630000 | — |
| fire_ruby | Fire Ruby | 12 | "Uncommon" | 1600000 | — |
| dragon_egg | Dragon Egg | 12 | "Legendary" | 63000000 | — |
| shadow_gem | Shadow Gem | 13 | "Common" | 2000000 | — |
| void_pearl | Void Pearl | 13 | "Uncommon" | 4900000 | — |
| dragon_scale | Ancient Dragon Scale | 13 | "Epic" | 49000000 | — |
| alien_goo | Alien Goo | 14 | "Common" | 6700000 | — |
| ufo_part | UFO Part | 14 | "Uncommon" | 17000000 | — |
| alien_artifact | Alien Artifact | 14 | "Rare" | 50000000 | — |
| alien_egg | Alien Egg | 14 | "Legendary" | 670000000 | — |
| core_fragment | Core Fragment | 15 | "Common" | 24000000 | — |
| molten_gold | Molten Gold | 15 | "Uncommon" | 60000000 | — |
| heart_of_the_earth | Heart of the Earth | 15 | "Legendary" | 2400000000 | — |
| beach_ball_of_creation | Beach Ball of Creation | 15 | "Mythic" | 9000000000 | — |
| sun_compass | A.D.'s Sun Compass | 1 | "Relic" | 0 | 1800 |
| tide_heart | Heart of the Tide | 3 | "Relic" | 0 | 2400 |

### Bottle Cap (`bottle_cap`)

```lua
{
		Id = "bottle_cap",
		Name = "Bottle Cap",
		Layer = 1,
		Rarity = "Common",
		SellValue = 8,
		FlavorText = "Somebody's soda. Gross, but it's a start!",
		Look = { Color = rgb(220, 60, 60), Shape = "Cap", Material = Enum.Material.Metal, Glow = false },
	}
```

### Lost Flip-Flop (`lost_flip_flop`)

```lua
{
		Id = "lost_flip_flop",
		Name = "Lost Flip-Flop",
		Layer = 1,
		Rarity = "Uncommon",
		SellValue = 20,
		FlavorText = "Every beach has one. Where is the other one?!",
		Look = { Color = rgb(60, 190, 255), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Cool Sunglasses (`cool_sunglasses`)

```lua
{
		Id = "cool_sunglasses",
		Name = "Cool Sunglasses",
		Layer = 1,
		Rarity = "Rare",
		SellValue = 60,
		FlavorText = "Instantly 200% cooler.",
		Look = { Color = rgb(30, 30, 40), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Seashell (`seashell`)

```lua
{
		Id = "seashell",
		Name = "Seashell",
		Layer = 2,
		Rarity = "Common",
		SellValue = 16,
		FlavorText = "A classic. Smells like the ocean.",
		Look = { Color = rgb(255, 200, 170), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Sand Dollar (`sand_dollar`)

```lua
{
		Id = "sand_dollar",
		Name = "Sand Dollar",
		Layer = 2,
		Rarity = "Uncommon",
		SellValue = 40,
		FlavorText = "Sadly, shops won't accept it. The sell stand will!",
		Look = { Color = rgb(240, 230, 200), Shape = "Coin", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Message in a Bottle (`message_in_a_bottle`)

```lua
{
		Id = "message_in_a_bottle",
		Name = "Message in a Bottle",
		Layer = 2,
		Rarity = "Rare",
		SellValue = 120,
		FlavorText = "'Dig deeper. The Core is real.' - A.D.",
		Look = { Color = rgb(120, 220, 180), Shape = "Bottle", Material = Enum.Material.Glass, Glow = false },
	}
```

### Conch Shell (`conch_shell`)

```lua
{
		Id = "conch_shell",
		Name = "Conch Shell",
		Layer = 3,
		Rarity = "Common",
		SellValue = 50,
		FlavorText = "Blow it to call the seagulls.",
		Look = { Color = rgb(255, 170, 150), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Glowing Pearl (`glowing_pearl`)

```lua
{
		Id = "glowing_pearl",
		Name = "Glowing Pearl",
		Layer = 3,
		Rarity = "Uncommon",
		SellValue = 120,
		FlavorText = "It glows a little brighter the deeper you go.",
		Look = { Color = rgb(255, 245, 255), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	}
```

### Giant Clam (`giant_clam`)

```lua
{
		Id = "giant_clam",
		Name = "Giant Clam",
		Layer = 3,
		Rarity = "Rare",
		SellValue = 360,
		FlavorText = "It's still a little grumpy about being dug up.",
		Look = { Color = rgb(170, 140, 255), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Rusty Anchor (`rusty_anchor`)

```lua
{
		Id = "rusty_anchor",
		Name = "Rusty Anchor",
		Layer = 4,
		Rarity = "Common",
		SellValue = 130,
		FlavorText = "From a boat that got stuck in the mud.",
		Look = { Color = rgb(150, 90, 60), Shape = "Anchor", Material = Enum.Material.CorrodedMetal, Glow = false },
	}
```

### Old Pocket Watch (`pocket_watch`)

```lua
{
		Id = "pocket_watch",
		Name = "Old Pocket Watch",
		Layer = 4,
		Rarity = "Uncommon",
		SellValue = 320,
		FlavorText = "Stopped at exactly high tide.",
		Look = { Color = rgb(220, 190, 80), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	}
```

### Mermaid's Comb (`mermaid_comb`)

```lua
{
		Id = "mermaid_comb",
		Name = "Mermaid's Comb",
		Layer = 4,
		Rarity = "Rare",
		SellValue = 960,
		FlavorText = "Mermaids lose these ALL the time.",
		Look = { Color = rgb(120, 240, 230), Shape = "Shard", Material = Enum.Material.Glass, Glow = true },
	}
```

### Gold Doubloon (`gold_doubloon`)

```lua
{
		Id = "gold_doubloon",
		Name = "Gold Doubloon",
		Layer = 5,
		Rarity = "Common",
		SellValue = 360,
		FlavorText = "Pirate money! Arrr.",
		Look = { Color = rgb(255, 205, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	}
```

### Pirate Hook (`pirate_hook`)

```lua
{
		Id = "pirate_hook",
		Name = "Pirate Hook",
		Layer = 5,
		Rarity = "Uncommon",
		SellValue = 900,
		FlavorText = "Captain Sandbeard's spare.",
		Look = { Color = rgb(190, 190, 200), Shape = "Anchor", Material = Enum.Material.Metal, Glow = false },
	}
```

### Treasure Map (`treasure_map`)

```lua
{
		Id = "treasure_map",
		Name = "Treasure Map",
		Layer = 5,
		Rarity = "Rare",
		SellValue = 2700,
		FlavorText = "The X is... below you. Way below.",
		Look = { Color = rgb(230, 200, 140), Shape = "Tablet", Material = Enum.Material.Fabric, Glow = false },
	}
```

### Pirate Chest (`pirate_chest`)

```lua
{
		Id = "pirate_chest",
		Name = "Pirate Chest",
		Layer = 5,
		Rarity = "Legendary",
		SellValue = 36000,
		FlavorText = "Sandbeard's legendary loot chest!",
		Look = { Color = rgb(150, 95, 45), Shape = "Chest", Material = Enum.Material.Wood, Glow = false },
	}
```

### Ship's Wheel (`ships_wheel`)

```lua
{
		Id = "ships_wheel",
		Name = "Ship's Wheel",
		Layer = 6,
		Rarity = "Common",
		SellValue = 960,
		FlavorText = "Steer the ship! Oh wait, it sank.",
		Look = { Color = rgb(140, 90, 50), Shape = "Wheel", Material = Enum.Material.Wood, Glow = false },
	}
```

### Captain's Spyglass (`captains_spyglass`)

```lua
{
		Id = "captains_spyglass",
		Name = "Captain's Spyglass",
		Layer = 6,
		Rarity = "Uncommon",
		SellValue = 2400,
		FlavorText = "Spot treasure from a mile away.",
		Look = { Color = rgb(200, 160, 60), Shape = "Bottle", Material = Enum.Material.Metal, Glow = false },
	}
```

### Cursed Skull (`cursed_skull`)

```lua
{
		Id = "cursed_skull",
		Name = "Cursed Skull",
		Layer = 6,
		Rarity = "Epic",
		SellValue = 24000,
		FlavorText = "It winks at you when nobody is looking.",
		Look = { Color = rgb(120, 255, 140), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = true },
	}
```

### Trilobite (`trilobite`)

```lua
{
		Id = "trilobite",
		Name = "Trilobite",
		Layer = 7,
		Rarity = "Common",
		SellValue = 2900,
		FlavorText = "A 500-million-year-old bug. Cute!",
		Look = { Color = rgb(140, 130, 110), Shape = "Shell", Material = Enum.Material.Slate, Glow = false },
	}
```

### Ammonite (`ammonite`)

```lua
{
		Id = "ammonite",
		Name = "Ammonite",
		Layer = 7,
		Rarity = "Uncommon",
		SellValue = 7200,
		FlavorText = "A spiral shell from the age of sea monsters.",
		Look = { Color = rgb(210, 170, 120), Shape = "Shell", Material = Enum.Material.Marble, Glow = false },
	}
```

### T-Rex Tooth (`trex_tooth`)

```lua
{
		Id = "trex_tooth",
		Name = "T-Rex Tooth",
		Layer = 7,
		Rarity = "Rare",
		SellValue = 22000,
		FlavorText = "Bigger than your hand. Imagine the smile.",
		Look = { Color = rgb(250, 245, 225), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Dino Skull (`dino_skull`)

```lua
{
		Id = "dino_skull",
		Name = "Dino Skull",
		Layer = 7,
		Rarity = "Legendary",
		SellValue = 290000,
		FlavorText = "The museum would pay a fortune for this.",
		Look = { Color = rgb(245, 235, 210), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Geode (`geode`)

```lua
{
		Id = "geode",
		Name = "Geode",
		Layer = 8,
		Rarity = "Common",
		SellValue = 7700,
		FlavorText = "Boring outside, sparkly inside.",
		Look = { Color = rgb(120, 110, 130), Shape = "Orb", Material = Enum.Material.Rock, Glow = false },
	}
```

### Iron Nugget (`iron_nugget`)

```lua
{
		Id = "iron_nugget",
		Name = "Iron Nugget",
		Layer = 8,
		Rarity = "Uncommon",
		SellValue = 19000,
		FlavorText = "Heavy, shiny, and useful for shovels.",
		Look = { Color = rgb(160, 160, 170), Shape = "Shard", Material = Enum.Material.Metal, Glow = false },
	}
```

### Ancient Arrowhead (`ancient_arrowhead`)

```lua
{
		Id = "ancient_arrowhead",
		Name = "Ancient Arrowhead",
		Layer = 8,
		Rarity = "Rare",
		SellValue = 58000,
		FlavorText = "Somebody explored down here before you.",
		Look = { Color = rgb(90, 90, 100), Shape = "Shard", Material = Enum.Material.Slate, Glow = false },
	}
```

### Amethyst (`amethyst`)

```lua
{
		Id = "amethyst",
		Name = "Amethyst",
		Layer = 9,
		Rarity = "Common",
		SellValue = 22000,
		FlavorText = "Purple and sparkly.",
		Look = { Color = rgb(170, 90, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Sapphire (`sapphire`)

```lua
{
		Id = "sapphire",
		Name = "Sapphire",
		Layer = 9,
		Rarity = "Uncommon",
		SellValue = 55000,
		FlavorText = "Deep blue, like the ocean far above.",
		Look = { Color = rgb(40, 110, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Glow Crystal (`glow_crystal`)

```lua
{
		Id = "glow_crystal",
		Name = "Glow Crystal",
		Layer = 9,
		Rarity = "Rare",
		SellValue = 160000,
		FlavorText = "This is what lights the caverns.",
		Look = { Color = rgb(140, 255, 250), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	}
```

### Rainbow Diamond (`rainbow_diamond`)

```lua
{
		Id = "rainbow_diamond",
		Name = "Rainbow Diamond",
		Layer = 9,
		Rarity = "Legendary",
		SellValue = 2200000,
		FlavorText = "Every colour at once!",
		Look = { Color = rgb(255, 140, 220), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Frozen Fish (`frozen_fish`)

```lua
{
		Id = "frozen_fish",
		Name = "Frozen Fish",
		Layer = 10,
		Rarity = "Common",
		SellValue = 66000,
		FlavorText = "It's been chilling for 10,000 years.",
		Look = { Color = rgb(150, 210, 255), Shape = "Box", Material = Enum.Material.Ice, Glow = false },
	}
```

### Mammoth Tusk (`mammoth_tusk`)

```lua
{
		Id = "mammoth_tusk",
		Name = "Mammoth Tusk",
		Layer = 10,
		Rarity = "Uncommon",
		SellValue = 160000,
		FlavorText = "The mammoth wants it back.",
		Look = { Color = rgb(245, 240, 220), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	}
```

### Ice Crown (`ice_crown`)

```lua
{
		Id = "ice_crown",
		Name = "Ice Crown",
		Layer = 10,
		Rarity = "Epic",
		SellValue = 1600000,
		FlavorText = "Crown of the Frost King. Never melts.",
		Look = { Color = rgb(190, 240, 255), Shape = "Crown", Material = Enum.Material.Ice, Glow = true },
	}
```

### Stone Tablet (`stone_tablet`)

```lua
{
		Id = "stone_tablet",
		Name = "Stone Tablet",
		Layer = 11,
		Rarity = "Common",
		SellValue = 190000,
		FlavorText = "Instructions for a giant shovel?",
		Look = { Color = rgb(170, 160, 140), Shape = "Tablet", Material = Enum.Material.Slate, Glow = false },
	}
```

### Golden Idol (`golden_idol`)

```lua
{
		Id = "golden_idol",
		Name = "Golden Idol",
		Layer = 11,
		Rarity = "Uncommon",
		SellValue = 480000,
		FlavorText = "Don't swap it with a bag of sand...",
		Look = { Color = rgb(255, 200, 50), Shape = "Skull", Material = Enum.Material.Metal, Glow = false },
	}
```

### Sun Mask (`sun_mask`)

```lua
{
		Id = "sun_mask",
		Name = "Sun Mask",
		Layer = 11,
		Rarity = "Rare",
		SellValue = 1400000,
		FlavorText = "The Sandlantis people worshipped the beach sun.",
		Look = { Color = rgb(255, 170, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = true },
	}
```

### Crown of Sandlantis (`atlantis_crown`)

```lua
{
		Id = "atlantis_crown",
		Name = "Crown of Sandlantis",
		Layer = 11,
		Rarity = "Legendary",
		SellValue = 19000000,
		FlavorText = "The crown of the lost underground city.",
		Look = { Color = rgb(255, 215, 80), Shape = "Crown", Material = Enum.Material.Metal, Glow = true },
	}
```

### Obsidian Shard (`obsidian_shard`)

```lua
{
		Id = "obsidian_shard",
		Name = "Obsidian Shard",
		Layer = 12,
		Rarity = "Common",
		SellValue = 630000,
		FlavorText = "Volcanic glass. Sharp!",
		Look = { Color = rgb(40, 30, 50), Shape = "Shard", Material = Enum.Material.Glass, Glow = false },
	}
```

### Fire Ruby (`fire_ruby`)

```lua
{
		Id = "fire_ruby",
		Name = "Fire Ruby",
		Layer = 12,
		Rarity = "Uncommon",
		SellValue = 1600000,
		FlavorText = "Warm to the touch. Very warm. OUCH.",
		Look = { Color = rgb(255, 40, 40), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	}
```

### Dragon Egg (`dragon_egg`)

```lua
{
		Id = "dragon_egg",
		Name = "Dragon Egg",
		Layer = 12,
		Rarity = "Legendary",
		SellValue = 63000000,
		FlavorText = "Something inside is moving...",
		Look = { Color = rgb(200, 50, 30), Shape = "Egg", Material = Enum.Material.Slate, Glow = true },
	}
```

### Shadow Gem (`shadow_gem`)

```lua
{
		Id = "shadow_gem",
		Name = "Shadow Gem",
		Layer = 13,
		Rarity = "Common",
		SellValue = 2000000,
		FlavorText = "Absorbs all light around it.",
		Look = { Color = rgb(80, 40, 120), Shape = "Gem", Material = Enum.Material.Glass, Glow = false },
	}
```

### Void Pearl (`void_pearl`)

```lua
{
		Id = "void_pearl",
		Name = "Void Pearl",
		Layer = 13,
		Rarity = "Uncommon",
		SellValue = 4900000,
		FlavorText = "Look inside and you see stars.",
		Look = { Color = rgb(40, 20, 80), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	}
```

### Ancient Dragon Scale (`dragon_scale`)

```lua
{
		Id = "dragon_scale",
		Name = "Ancient Dragon Scale",
		Layer = 13,
		Rarity = "Epic",
		SellValue = 49000000,
		FlavorText = "Harder than any shovel... almost.",
		Look = { Color = rgb(150, 30, 200), Shape = "Shard", Material = Enum.Material.Metal, Glow = true },
	}
```

### Alien Goo (`alien_goo`)

```lua
{
		Id = "alien_goo",
		Name = "Alien Goo",
		Layer = 14,
		Rarity = "Common",
		SellValue = 6700000,
		FlavorText = "Squishy. Do NOT eat it.",
		Look = { Color = rgb(110, 255, 120), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### UFO Part (`ufo_part`)

```lua
{
		Id = "ufo_part",
		Name = "UFO Part",
		Layer = 14,
		Rarity = "Uncommon",
		SellValue = 17000000,
		FlavorText = "Looks important. Probably from the engine.",
		Look = { Color = rgb(180, 190, 200), Shape = "Wheel", Material = Enum.Material.Metal, Glow = true },
	}
```

### Alien Artifact (`alien_artifact`)

```lua
{
		Id = "alien_artifact",
		Name = "Alien Artifact",
		Layer = 14,
		Rarity = "Rare",
		SellValue = 50000000,
		FlavorText = "It hums a song about the Core.",
		Look = { Color = rgb(90, 255, 200), Shape = "Tablet", Material = Enum.Material.Neon, Glow = true },
	}
```

### Alien Egg (`alien_egg`)

```lua
{
		Id = "alien_egg",
		Name = "Alien Egg",
		Layer = 14,
		Rarity = "Legendary",
		SellValue = 670000000,
		FlavorText = "Not a chicken egg. Definitely not.",
		Look = { Color = rgb(150, 255, 90), Shape = "Egg", Material = Enum.Material.Neon, Glow = true },
	}
```

### Core Fragment (`core_fragment`)

```lua
{
		Id = "core_fragment",
		Name = "Core Fragment",
		Layer = 15,
		Rarity = "Common",
		SellValue = 24000000,
		FlavorText = "A piece of the planet's golden heart.",
		Look = { Color = rgb(255, 190, 40), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	}
```

### Molten Gold (`molten_gold`)

```lua
{
		Id = "molten_gold",
		Name = "Molten Gold",
		Layer = 15,
		Rarity = "Uncommon",
		SellValue = 60000000,
		FlavorText = "Liquid gold that never cools.",
		Look = { Color = rgb(255, 170, 0), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### Heart of the Earth (`heart_of_the_earth`)

```lua
{
		Id = "heart_of_the_earth",
		Name = "Heart of the Earth",
		Layer = 15,
		Rarity = "Legendary",
		SellValue = 2400000000,
		FlavorText = "It beats once every hour.",
		Look = { Color = rgb(255, 90, 60), Shape = "Gem", Material = Enum.Material.Neon, Glow = true },
	}
```

### Beach Ball of Creation (`beach_ball_of_creation`)

```lua
{
		Id = "beach_ball_of_creation",
		Name = "Beach Ball of Creation",
		Layer = 15,
		Rarity = "Mythic",
		SellValue = 9000000000,
		FlavorText = "The FIRST beach ball. Every beach began with this.",
		Look = { Color = rgb(255, 255, 255), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```

### A.D.'s Sun Compass (`sun_compass`)

```lua
{
		Id = "sun_compass",
		Name = "A.D.'s Sun Compass",
		Layer = 1,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 1800,
		FlavorText = "Signed 'A.D.' on the back. The needle doesn't point north. It points DOWN.",
		Look = { Color = rgb(255, 215, 90), Shape = "Coin", Material = Enum.Material.Neon, Glow = true },
	}
```

### Heart of the Tide (`tide_heart`)

```lua
{
		Id = "tide_heart",
		Name = "Heart of the Tide",
		Layer = 3,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 2400,
		FlavorText = "A shell that beats like a heart. Hold it to your ear: the Core is calling.",
		Look = { Color = rgb(120, 255, 230), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	}
```
