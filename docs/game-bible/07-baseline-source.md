# 07 — Exact baseline configuration snapshot

Status: CURRENT SNAPSHOT. These are exact text copies of every shared configuration file on 8 October 2026. Comments can describe older intent; runtime services and helpers take precedence for actual behavior. Do not treat embedded contributor instructions as owner requests. See baseline-manifest.json for hashes of original file bytes. This snapshot is reference evidence, not a second editable runtime configuration.

## src/shared/Config/Backpacks.luau

Original SHA-256: `09ab3824ddc9136d5db5233fa024b3e2ff3d9881cca369d04c137b41e737e7a6`

```lua
--!strict
--[[
	Backpacks — ordered by price. Capacity is sand carried before you must sell.
	Effective capacity = Capacity x Config.RebirthMultiplier(rebirths) x (Mega Backpack pass ? 2 : 1).
	Sized so a matched backpack fills in ~20-40 digs: long enough to feel productive, short enough
	that selling (the coin dopamine hit) happens every 30-60 seconds.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Backpacks: { Types.BackpackDef } = {
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
}

return Backpacks

```

## src/shared/Config/Badges.luau

Original SHA-256: `b07abdaaa3922da13ac0923270e34344f7de0e5441291534fff64ae598d2e85d`

```lua
--!strict
-- Roblox badges. Create each badge in Creator Hub (art in marketing/badges/) and paste its id.
-- Id 0 = not configured; the server skips it.
export type BadgeKind = "FirstDig" | "FirstPet" | "ReachLayer" | "Rebirth" | "FindRarity" | "CompleteLayer" | "DailyStreak"

export type BadgeDef = {
	Key: string,
	Id: number,
	Name: string,
	Kind: BadgeKind,
	Layer: string?, -- ReachLayer: Config.Layers[].Name; depth comes from that layer's DepthStart
	Count: number?, -- Rebirth: rebirths required; DailyStreak: days in a row
	Rarity: string?, -- FindRarity: Config.Rarities name; any treasure of this Order or higher in the Index counts
}

local Badges: { BadgeDef } = {
	{ Key = "Welcome", Id = 305615989875213, Name = "Welcome to the Beach!", Kind = "FirstDig" },
	{ Key = "FirstPet", Id = 1399687731914868, Name = "New Best Friend", Kind = "FirstPet" },
	{
		Key = "PirateCove",
		Id = 3721202346547107,
		Name = "Arrr, Pirate Cove!",
		Kind = "ReachLayer",
		Layer = "Pirate Cove",
	},
	{ Key = "FossilBed", Id = 1841450014262918, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" },
	{
		Key = "CrystalCaverns",
		Id = 3808710393122420,
		Name = "Crystal Clear",
		Kind = "ReachLayer",
		Layer = "Crystal Caverns",
	},
	{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" },
	{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" },
	{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" },
	{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" },
	{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 },
	-- Wave 2 (art: marketing/badges/11..15)
	{ Key = "MythicLuck", Id = 0, Name = "Mythic Luck", Kind = "FindRarity", Rarity = "Mythic" },
	{ Key = "Collector", Id = 0, Name = "Collector", Kind = "CompleteLayer" },
	{ Key = "AncientRuins", Id = 0, Name = "Lost Civilization", Kind = "ReachLayer", Layer = "Ancient Ruins" },
	{ Key = "BeachRegular", Id = 0, Name = "Beach Regular", Kind = "DailyStreak", Count = 7 },
	{ Key = "CoreBreaker", Id = 0, Name = "Core Breaker", Kind = "Rebirth", Count = 10 },
}

return Badges

```

## src/shared/Config/Boosts.luau

Original SHA-256: `d401a6db4cd09e9e5834e7a823b414c35f3e0a62ee3adcda45d5b24c33bb8b19`

```lua
--!strict
--[[
	Boosts — timed multipliers stored in PlayerData.Boosts[boostId] = expiresUnix.
	Buying/earning a boost you already have ADDS time (stacks duration, not multiplier).
	Sources: developer products (15 min), quests, daily rewards, codes.
	Kinds: Sand (sand per dig), Luck (treasure chance & non-Common weights, egg luck),
	Coins (coins when selling), Speed (dig cooldown divided by Multiplier).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Boosts: { Types.BoostDef } = {
	{
		Id = "SandBoost",
		Name = "2x Sand",
		Kind = "Sand",
		Multiplier = 2,
		Description = "Double sand from every dig!",
		Color = rgb(255, 205, 60),
	},
	{
		Id = "LuckBoost",
		Name = "2x Luck",
		Kind = "Luck",
		Multiplier = 2,
		Description = "Double treasure chance and better pets from eggs!",
		Color = rgb(90, 230, 120),
	},
	{
		Id = "CoinBoost",
		Name = "2x Coins",
		Kind = "Coins",
		Multiplier = 2,
		Description = "Double coins every time you sell!",
		Color = rgb(255, 170, 30),
	},
	{
		Id = "SpeedBoost",
		Name = "Fast Dig",
		Kind = "Speed",
		Multiplier = 1.5,
		Description = "Dig 50% faster!",
		Color = rgb(60, 190, 255),
	},
	-- v2 survival: short snack boosts (Config.Consumables). Weaker than the Robux boosts on purpose.
	{
		Id = "SugarRush",
		Name = "Sugar Rush",
		Kind = "Speed",
		Multiplier = 1.25,
		Description = "Brain freeze! Dig 25% faster for a little while.",
		Color = rgb(255, 120, 200),
	},
	{
		Id = "MelonPower",
		Name = "Melon Power",
		Kind = "Sand",
		Multiplier = 1.5,
		Description = "Juicy! +50% sand for a little while.",
		Color = rgb(90, 220, 110),
	},
}

return Boosts

```

## src/shared/Config/Codes.luau

Original SHA-256: `f3df285af7d534a15b34acff2509ab5abb5504468bf58bb723171544269b27b8`

```lua
--!strict
--[[
	Codes — redeemable via Remotes.RedeemCode(code). Matched case-insensitively and with spaces
	trimmed (Config.GetCode). One redemption per player (PlayerData.RedeemedCodes[CODE] = true).
	Flip Enabled = true and republish when a milestone hits (e.g. 1KLIKES at 1,000 likes) and
	announce it in the group/Discord — codes are the #1 reason kids join the community.
	Expires is a unix timestamp (nil = never).
]]

local Types = require(script.Parent.Parent.Types)

local Codes: { Types.CodeDef } = {
	{
		Code = "RELEASE",
		Reward = { ScaledCoins = 300, Coins = 500, Pet = "launch_crab" },
		Enabled = true,
		Expires = nil,
		Note = "Launch code. Gives the exclusive Launch Party Crab.",
	},
	{
		Code = "SANDY",
		Reward = { Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Expires = nil,
		Note = "Evergreen code shown on the loading screen / game description.",
	},
	{
		Code = "DIGDEEP",
		Reward = { Boost = "LuckBoost", BoostSeconds = 900, Egg = "beach_egg", EggCount = 1 },
		Enabled = true,
		Expires = nil,
		GroupOnly = true,
		Note = "Group code: post it in the Roblox group and Discord.",
	},
	{
		Code = "1KLIKES",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = false,
		Expires = nil,
		Note = "Enable when the game reaches 1,000 likes.",
	},
}

return Codes

```

## src/shared/Config/Consumables.luau

Original SHA-256: `dfda46f04d136ab4487ddad173b51485774d66ea659e1559442ce53e382c0a76`

```lua
--!strict
--[[
	Consumables — drinks & snacks (owner: Survival). Bought with coins into
	PlayerData.Consumables[id] (count), used from the HUD quick-slots (keys 1/2/3).

	Cooling      = heat removed instantly (Config.Heat.Max = 100).
	Boost        = Config.Boosts id granted on use for BoostSeconds (snack boosts stack time up to
	               Config.Heat.ConsumableBoostCapSeconds).
	Price 0      = not sold: water is free and unlimited, but only at the hub fountain
	               (DrinkFountain).
	Look.Style picks the model builder in Models/Consumables.luau.
]]
local Types = require(script.Parent.Parent.Types)
local Boosts = require(script.Parent.Boosts)

local rgb = Color3.fromRGB

local Consumables: { Types.ConsumableDef } = {
	{
		Id = "water",
		Name = "Fountain Water",
		Price = 0,
		Cooling = 70,
		Icon = "💧",
		Description = "Free at the fountain! Cools you right down.",
		Look = { Style = "Bottle", Color = rgb(120, 200, 255) },
	},
	{
		Id = "lemonade",
		Name = "Lemonade",
		Price = 40,
		Cooling = 35,
		Icon = "🍋",
		Description = "Fresh and fizzy. A quick cool-down.",
		Look = { Style = "Cup", Color = rgb(255, 235, 90) },
	},
	{
		Id = "coconut_water",
		Name = "Coconut Water",
		Price = 250,
		Cooling = 60,
		Icon = "🥥",
		Description = "Straight from the palm tree. Big cool-down.",
		Look = { Style = "Coconut", Color = rgb(130, 85, 50) },
	},
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
	},
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
	},
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
	},
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
	},
}

-- Sanity: boost ids must exist.
do
	local boostIds: { [string]: boolean } = {}
	for _, boost in Boosts do
		boostIds[boost.Id] = true
	end
	for _, def in Consumables do
		if def.Boost then
			assert(boostIds[def.Boost], "Consumables: unknown boost " .. def.Boost .. " on " .. def.Id)
		end
	end
end

return Consumables

```

## src/shared/Config/DailyRewards.luau

Original SHA-256: `5c71a7dae3b0e450e5e0455a10bd1c15d878bd505afae324c27730fda72d6c18`

```lua
--!strict
--[[
	DailyRewards — 7-day streak. Claimable once Config.DAILY_COOLDOWN_SECONDS (20h) passed since
	LastDailyClaim. If more than Config.DAILY_STREAK_GRACE_SECONDS (48h) passed, the streak resets to
	day 1. After day 7 the cycle repeats from day 1 (DailyStreak keeps counting for badges/UI;
	reward index = ((DailyStreak - 1) % 7) + 1). Premium players get coin rewards
	x Config.Monetization.Premium.DailyRewardMultiplier.
]]

local Types = require(script.Parent.Parent.Types)

local DailyRewards: { Types.DailyRewardDef } = {
	{ Day = 1, Label = "Coins", Reward = { ScaledCoins = 120, Coins = 100 } },
	{ Day = 2, Label = "2x Sand (15 min)", Reward = { Boost = "SandBoost", BoostSeconds = 900 } },
	{ Day = 3, Label = "Big Coins", Reward = { ScaledCoins = 300, Coins = 250 } },
	{ Day = 4, Label = "2x Luck (15 min)", Reward = { Boost = "LuckBoost", BoostSeconds = 900 } },
	{ Day = 5, Label = "Free Eggs", Reward = { Egg = "beach_egg", EggCount = 3 } },
	{ Day = 6, Label = "Huge Coins + Token", Reward = { ScaledCoins = 600, Coins = 500, RebirthTokens = 1 } },
	{
		Day = 7,
		Label = "Sunny Seal Pet!",
		Reward = { Pet = "sunny_seal", Boost = "CoinBoost", BoostSeconds = 1800 },
	},
}

return DailyRewards

```

## src/shared/Config/Discovery.luau

Original SHA-256: `dd7427f6546f8de5cc46450d560847d7128b5bda93efb7d9729e7ea0ffb0edc4`

```lua
--!strict
--[[
	Discovery (v3 slice) — buried finds, the detector, the excavation minigame and rarity
	presentation. Read-only balance data; the logic lives in Shared/Util/Finds.luau (pure, used by
	server and client) and Services/DiscoveryService.luau. Design + odds tables:
	docs/design/Discovery.md.

	Deposits are pure server data in "chunks" (CHUNK x CHUNK_Y x CHUNK studs of the dig zone,
	seeded lazily the first time anything looks at them). A digging carve that comes within
	UncoverRadius studs of a deposit uncovers it; the first player to uncover it owns the
	excavation. Variants (size + material) are rolled when the deposit is uncovered, so the
	uncoverer's luck applies (true odds shown in the Index); the treasure itself is rolled at
	seeding so the detector can hint its tier.
]]

local Types = require(script.Parent.Parent.Types)

export type VariantDef = {
	Id: string,
	Name: string, -- shown before the item name ("Giant", "Golden"); "" for the default
	Short: string, -- 1-4 letter Index pill label (no emoji: TextScaled labels)
	Weight: number, -- base odds weight (all weights of a group sum to 100 = percent)
	ValueMultiplier: number,
	Lucky: boolean, -- luck multiplies this weight (rarer-than-default variants)
	Scale: number?, -- size variants: model scale
	Color: Color3, -- Index pill / reveal row colour
}

export type QualityDef = {
	Id: Types.FindQuality,
	Name: string,
	MinScore: number, -- excavation score (Perfect = 2, Good = 1 per ring) needed
	ValueMultiplier: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

local Discovery = {
	-- Seeding ---------------------------------------------------------------------------------
	CHUNK = 32, -- chunk size in X and Z (studs)
	CHUNK_Y = 16, -- chunk height (studs): the top band (depth 3-16) is what a new player reaches first
	MIN_DEPTH = 3, -- deposits sit at least this far below the surface (visible surface ~2 above grid)
	EDGE_MARGIN = 1.5, -- studs kept clear of the zone walls / floor
	MIN_SPACING = 5, -- studs between two deposits of the same chunk
	CHUNK_CAP = 16, -- never more deposits than this in one chunk
	SERVER_CAP = 4000, -- never more deposits than this on the server (oldest chunks evicted)
	RESPAWN_SECONDS = 90, -- a chunk below its target regrows one deposit this often
	EVICT_SECONDS = 300, -- chunks nobody touched for this long are forgotten (re-seeded fresh)
	-- Deposits per chunk (32 x 16 x 32 studs) by layer index (fraction = chance of one more).
	-- Layer 1 is calibrated in tests (starter Hand Spade standing still: ~1 find / 30-60 s);
	-- deeper layers scale by 1 / sweep of that layer's typical shovel, sweep = (edge + 5)^2 x
	-- edge / cooldown (edge = carved cube, + 2 x UNCOVER_RADIUS margin), so finds per SECOND
	-- stay about the same while finds per stud get rarer (docs/design/Discovery.md).
	DENSITY = { 10, 10, 9, 10, 10, 3, 2.7, 2.5, 2.2, 0.8, 0.7, 0.6, 0.55, 0.25, 0.2 } :: { number },

	-- Uncovering -------------------------------------------------------------------------------
	UNCOVER_RADIUS = 3, -- a carve within this many studs of a deposit uncovers it
	-- Ambient junk: a tiny per-dig chance of a Common treasure straight into the backpack (no
	-- minigame), = layer.TreasureChance x luck x this. Keeps a little popcorn between deposits.
	AMBIENT_FACTOR = 0.1,
	-- FTUE: a brand-new player's Nth successful dig always uncovers a Common find right there.
	FTUE_FIND_DIG = 6,

	-- Relics (rarity "Relic"): any deposit has this chance to hold a Relic whose Layer <= the
	-- deposit's layer. Relic value = TreasureDef.ScaledValue seconds of income (RewardScale of the
	-- player's deepest layer), so a Relic is a jackpot at every stage of the game.
	RELIC_CHANCE = 1 / 400,

	-- Detector -----------------------------------------------------------------------------------
	DETECTOR_RANGE = 24, -- studs (upgradeable later)
	SCAN_SECONDS = 6, -- one Scan pings for this long...
	SCAN_COOLDOWN = 8, -- ...and can be started again this long after the previous start
	PING_INTERVAL = 0.5, -- seconds between DetectorPing updates during a scan
	-- Distance bands (studs): band 1 = hot (< 6), 2 (< 12), 3 (< 18), 4 (< range), 0 = nothing.
	BANDS = { 6, 12, 18 } :: { number },
	SECTORS = 8, -- horizontal direction is quantised to this many compass sectors
	VERTICAL_LEVEL = 4, -- |dy| under this many studs reads "Level"
	-- "Dig straight down here": the find is below (or above) and its horizontal offset is under
	-- max(OVERHEAD_MIN, |dy| x OVERHEAD_SLOPE). Walking would not help, so the detector says so
	-- instead of showing a wobbling compass sector.
	OVERHEAD_MIN = 3,
	OVERHEAD_SLOPE = 0.5,
	-- Detector signal colour by rarity (hints the tier, never the item).
	SIGNAL_BY_RARITY = {
		Common = "White",
		Uncommon = "White",
		Rare = "Gold",
		Epic = "Gold",
		Legendary = "Gold",
		Mythic = "Purple",
		Relic = "Purple",
	} :: { [string]: Types.DetectorSignal },
	SIGNAL_COLORS = {
		White = rgb(235, 240, 255),
		Gold = rgb(255, 200, 40),
		Purple = rgb(190, 90, 255),
	} :: { [string]: Color3 },

	-- Excavation minigame -------------------------------------------------------------------------
	RINGS = 3, -- timed taps
	RING_SECONDS = 0.9, -- a ring shrinks onto the target in this long
	RING_GAP = 0.25, -- pause between rings
	PERFECT_WINDOW = 0.09, -- |tap - target| <= this: Perfect (2 points)
	GOOD_WINDOW = 0.22, -- <= this: Good (1 point); later / earlier / no tap: Miss (0)
	-- Server checks (anti-cheat; quality only changes value, so cheating gains at most x1.5/x1):
	MIN_EXCAVATION_SECONDS = 1.6, -- answered faster than this -> quality capped at Good
	EXCAVATION_TIMEOUT = 9, -- no answer by then -> resolved with no hits (Damaged, never lost)
	REVEAL_SECONDS = 5, -- the dug-up model stays in the world this long after the reveal
	SPECTACLE_SECONDS = 12, -- Mythic / Relic models (with their sky beam) stay this long

	-- Variants -------------------------------------------------------------------------------------
	SIZES = {
		{
			Id = "Tiny",
			Name = "Tiny",
			Short = "XS",
			Weight = 20,
			ValueMultiplier = 0.5,
			Lucky = false,
			Scale = 0.6,
			Color = rgb(170, 210, 255),
		},
		{
			Id = "Normal",
			Name = "",
			Short = "M",
			Weight = 62,
			ValueMultiplier = 1,
			Lucky = false,
			Scale = 1,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Large",
			Name = "Large",
			Short = "L",
			Weight = 14,
			ValueMultiplier = 2,
			Lucky = true,
			Scale = 1.5,
			Color = rgb(120, 230, 120),
		},
		{
			Id = "Giant",
			Name = "Giant",
			Short = "XL",
			Weight = 4,
			ValueMultiplier = 5,
			Lucky = true,
			Scale = 2.4,
			Color = rgb(255, 140, 60),
		},
	} :: { VariantDef },
	MATERIALS = {
		{
			Id = "None",
			Name = "",
			Short = "-",
			Weight = 88,
			ValueMultiplier = 1,
			Lucky = false,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Golden",
			Name = "Golden",
			Short = "Gold",
			Weight = 7,
			ValueMultiplier = 3,
			Lucky = true,
			Color = rgb(255, 205, 40),
		},
		{
			Id = "Fossilized",
			Name = "Fossilized",
			Short = "Fos",
			Weight = 3.5,
			ValueMultiplier = 5,
			Lucky = true,
			Color = rgb(170, 140, 110),
		},
		{
			Id = "Crystal",
			Name = "Crystal",
			Short = "Cry",
			Weight = 1.5,
			ValueMultiplier = 10,
			Lucky = true,
			Color = rgb(120, 230, 255),
		},
	} :: { VariantDef },
	QUALITIES = {
		{ Id = "Damaged", Name = "Damaged", MinScore = 0, ValueMultiplier = 0.6, Color = rgb(200, 150, 120) },
		{ Id = "Good", Name = "Good", MinScore = 2, ValueMultiplier = 1, Color = rgb(235, 235, 235) },
		{ Id = "Pristine", Name = "Pristine", MinScore = 5, ValueMultiplier = 1.5, Color = rgb(120, 255, 200) },
	} :: { QualityDef },

	-- Presentation tier by rarity (Finds.Tier also bumps a Pop to a Beam for Giant / material finds).
	TIER_BY_RARITY = {
		Common = "Pop",
		Uncommon = "Pop",
		Rare = "Beam",
		Epic = "Card",
		Legendary = "Card",
		Mythic = "Server",
		Relic = "Spectacle",
	} :: { [string]: Types.FindTier },
}

return Discovery

```

## src/shared/Config/Eggs.luau

Original SHA-256: `861afbc987e851571c0e06fddf0d9f41ef2ece72a42fff8e5830d3b56df0880c`

```lua
--!strict
--[[
	Eggs — hatch pets. Coin eggs unlock when your MaxDepth reaches the layer UnlockLayer
	(Config.IsEggUnlocked). Weights are relative (they sum to 100 for readability).
	Rebirth Egg and Golden Egg cost Rebirth Tokens (v2.3: the Golden Egg is no longer sold for
	Robux; Config rejects any egg with Currency "Robux").
	Luck boosts multiply the weight of non-Common pets; Triple Hatch pass hatches 3 at once.

	v2.1: Construction Crates (Kind = "Crate") are eggs that hatch digging vehicle pets (see
	Config/Pets.luau and docs/design/Companions.md). Same hatch flow, prices and unlocks; the world
	builds them in a small crate yard next to the plaza and the UI draws them as crates. The top
	crate hides the rideable Mythic "mega_excavator" (0.5%).

	v2.2 PITY (PityAt): after PityAt hatches IN A ROW without a Rare-or-better pet, the next hatch
	of that egg is guaranteed Rare+ (re-rolled among the Rare+ entries by their relative weights).
	Counter per egg in PlayerData.Pity, reset by any Rare+ hatch. Odds shown in the egg panel and
	rolled on the server come from the same function, Stats.GetHatchOdds. Tuning (base Rare+ chance
	-> chance a player ever reaches pity on a streak):
	  Beach Egg 2% -> 40 (cheap egg, ~45% of 40-streaks)    other coin eggs 12% -> 30 (~2%)
	  Cosmic Egg 30% -> 25 (almost never)                   Sandbox/Quarry/Mine Crate 7% -> 35 (~8%)
	  Core Crate 38% -> 25 (almost never)                   Rebirth / Golden Egg: all Rare+, no pity
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Eggs: { Types.EggDef } = {
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
	-- v2.1 Construction Crates ------------------------------------------------------------------
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
	},
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
	},
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
	},
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
	},
}

return Eggs

```

## src/shared/Config/Events.luau

Original SHA-256: `6531688dbf9474b5b1c194b678386d83fb8dfbfe6f2279ea946538e4ba8af98a`

```lua
--!strict
--[[
	Events — server-wide timed events, deterministic from os.time() so every server agrees
	without messaging: active while (os.time() + OffsetSeconds) % IntervalSeconds < DurationSeconds.
	Use Config.GetActiveEvents(now) to evaluate. The UI should show a countdown banner
	("High Tide in 2:31!") — anticipation is half the fun and pulls players back online.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Events: { Types.EventDef } = {
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
	},
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
	},
}

return Events

```

## src/shared/Config/Heat.luau

Original SHA-256: `8f00b2553f3fb4f3328e827fa898aabced76023115d5715cdaf84da08f570a32`

```lua
--!strict
--[[
	Heat — the soft survival meter (owner: Survival). See docs/design/Survival.md.

	The server (SurvivalService) ticks every player's heat every TickSeconds:
	  underground (Depth >= UndergroundDepth)  -> falls UndergroundFallPerSecond
	  under any placed shade                   -> falls ShadeFallPerSecond x best shade Cooling
	  on the hot sand in the sun               -> rises SunRisePerSecond x event multiplier
	                                              + DigRisePerDig per dig (max DigRiseMaxPerSecond)
	  anywhere else (boardwalk, hub, the sea)  -> falls OffSandFallPerSecond
	At SunburntAt the player is Sunburnt (dig cooldown x SunburntCooldownMultiplier) until heat
	falls to RecoverAt. Never damage, never death.

	Tuning targets (fresh player, toy shovel at 2 digs/s, full sun, no shade / drinks):
	  0.45/s sun + 2 x 0.12/s digging = 0.69/s  ->  100 heat in ~145 s (~2.4 min) of digging,
	  ~220 s standing still. Fountain water (-70) fixes Sunburnt instantly; a Beach Umbrella
	  takes 100 -> 40 in 20 s. New players get NewPlayerGraceSeconds of total play time with no
	  heat gain (the FTUE stays heat-free until the first umbrella is nearly affordable).
]]
local Types = require(script.Parent.Parent.Types)

local Heat: Types.HeatConfig = {
	Max = 100,
	TickSeconds = 0.25,

	SunRisePerSecond = 0.45,
	DigRisePerDig = 0.12,
	DigRiseMaxPerSecond = 0.3,

	ShadeFallPerSecond = 3,
	UndergroundDepth = 12,
	UndergroundFallPerSecond = 2.5,
	OffSandFallPerSecond = 1.5,

	WarningAt = 75,
	SunburntAt = 100,
	RecoverAt = 40,
	SunburntCooldownMultiplier = 1.6,
	NewPlayerGraceSeconds = 180,

	-- Golden Hour: the low sun is hotter. High Tide: a cool sea breeze.
	EventSunMultipliers = {
		GoldenHour = 1.35,
		HighTide = 0.6,
	},

	FountainCooldownSeconds = 3,
	ConsumableMaxStack = 99,
	ConsumableBoostCapSeconds = 300,

	ShadeSlots = 1,
	ShadeSlotsVip = 2,
	ShadePlaceRange = 30,
	ShadeMinSpacing = 4,
	ShadeHubClearance = 10,
}

return Heat

```

## src/shared/Config/IconAtlas.luau

Original SHA-256: `a85ea2fc7ff5244637d53757dbfcf9769aa106182f65da24086d95378979deaa`

```lua
--!strict
--[[
	IconAtlas — GENERATED by tools/icons/generate_icons.py (re-run it after changing icons; the
	generator keeps the ASSET_ID below). Source art: assets/icons/atlas.png, 1024x1024, an 8x8 grid
	of 128x128 cells; Icons[name] is the cell's ImageRectOffset in pixels.

	Usage on an ImageLabel / ImageButton:
		local offset = IconAtlas.Resolve("coins") -- or a UI/Icons.luau key: IconAtlas.Resolve("Coins")
		if IconAtlas.AssetId ~= "" and offset then
			label.Image = IconAtlas.AssetId
			label.ImageRectOffset = offset
			label.ImageRectSize = Vector2.new(IconAtlas.CellSize, IconAtlas.CellSize)
		else -- fall back to the emoji text from UI/Icons.luau
		end
	Grouped Icons.luau tables (Icons.Layers, Icons.PetShapes, ...): Groups[group][key] or
	Groups[group].Default.

	UPLOADING THE ATLAS (owner, once per change of atlas.png):
	  1. Studio -> View -> Asset Manager -> Bulk Import -> choose assets/icons/atlas.png
	     (or Creator Hub -> Creations -> Development Items -> Decals/Images -> Upload).
	  2. Copy the IMAGE asset id, NOT the decal id. In Studio, insert the uploaded decal into the
	     Workspace and look at its Texture/Image property: "rbxassetid://<id>" — that <id> is the
	     image id. (Asset Manager -> right-click the image -> Copy Asset ID also gives the image id.)
	     The decal id from the website URL is a different number and will show a blank image.
	  3. Paste it below:  local ASSET_ID = "rbxassetid://<id>"
	While ASSET_ID is "" the UI should keep using the emoji icons (UI/Icons.luau).
]]

local ASSET_ID = "rbxassetid://97869519007106"

local Icons: { [string]: Vector2 } = {
	coins = Vector2.new(0, 0),
	tokens = Vector2.new(128, 0),
	sand = Vector2.new(256, 0),
	backpack = Vector2.new(384, 0),
	shovel = Vector2.new(512, 0),
	spade = Vector2.new(640, 0),
	pickaxe = Vector2.new(768, 0),
	depth = Vector2.new(896, 0),
	layer = Vector2.new(0, 128),
	trophy = Vector2.new(128, 128),
	multiplier = Vector2.new(256, 128),
	shop = Vector2.new(384, 128),
	beach_shop = Vector2.new(512, 128),
	eggs = Vector2.new(640, 128),
	crate = Vector2.new(768, 128),
	pets = Vector2.new(896, 128),
	index = Vector2.new(0, 256),
	quests = Vector2.new(128, 256),
	daily = Vector2.new(256, 256),
	gift = Vector2.new(384, 256),
	rebirth = Vector2.new(512, 256),
	store = Vector2.new(640, 256),
	settings = Vector2.new(768, 256),
	surface = Vector2.new(896, 256),
	sell = Vector2.new(0, 384),
	auto = Vector2.new(128, 384),
	ride = Vector2.new(256, 384),
	place_shade = Vector2.new(384, 384),
	heat = Vector2.new(512, 384),
	sun = Vector2.new(640, 384),
	shade = Vector2.new(768, 384),
	water = Vector2.new(896, 384),
	lemonade = Vector2.new(0, 512),
	coconut = Vector2.new(128, 512),
	popsicle = Vector2.new(256, 512),
	shaved_ice = Vector2.new(384, 512),
	watermelon_slice = Vector2.new(512, 512),
	giant_watermelon = Vector2.new(640, 512),
	boost_sand = Vector2.new(768, 512),
	boost_luck = Vector2.new(896, 512),
	boost_speed = Vector2.new(0, 640),
	boost_coins = Vector2.new(128, 640),
	golden_hour = Vector2.new(256, 640),
	high_tide = Vector2.new(384, 640),
	treasure = Vector2.new(512, 640),
	egg_hatch = Vector2.new(640, 640),
	lock = Vector2.new(768, 640),
	check = Vector2.new(896, 640),
	close = Vector2.new(0, 768),
	arrow_right = Vector2.new(128, 768),
	arrow_down = Vector2.new(256, 768),
	star = Vector2.new(384, 768),
	notify = Vector2.new(512, 768),
	music = Vector2.new(640, 768),
	sfx = Vector2.new(768, 768),
	codes = Vector2.new(896, 768),
	info = Vector2.new(0, 896),
	power = Vector2.new(128, 896),
	radius = Vector2.new(256, 896),
	hand = Vector2.new(384, 896),
	gem = Vector2.new(512, 896),
	shell = Vector2.new(640, 896),
	crab = Vector2.new(768, 896),
	hourglass = Vector2.new(896, 896),
}

-- UI/Icons.luau key -> atlas icon name
local Aliases: { [string]: string } = {
	Coins = "coins",
	Tokens = "tokens",
	Rebirth = "rebirth",
	Sand = "sand",
	Backpack = "backpack",
	Depth = "depth",
	Shop = "shop",
	Eggs = "eggs",
	Pets = "pets",
	Index = "index",
	Quests = "quests",
	Daily = "daily",
	Store = "store",
	Settings = "settings",
	Beach = "beach_shop",
	Garage = "ride",
	Dig = "pickaxe",
	Ride = "ride",
	Crate = "crate",
	Surface = "surface",
	Sell = "sell",
	AutoDig = "auto",
	Lock = "lock",
	Check = "check",
	Close = "close",
	Star = "star",
	Robux = "store",
	Power = "power",
	Speed = "boost_speed",
	Radius = "radius",
	Multiplier = "multiplier",
	Hand = "hand",
	Arrow = "arrow_down",
}

-- UI/Icons.luau grouped tables -> atlas icon name (per-key overrides, else Default)
local Groups: { [string]: { [string]: string } } = {
	Layers = {
		Default = "layer",
		crystal_caverns = "gem",
		shell_bed = "shell",
		tidal_clay = "crab",
		shipwreck = "treasure",
		the_core = "sun",
		dry_sand = "sand",
		wet_sand = "high_tide",
	},
	PetShapes = {
		Default = "pets",
		Crab = "crab",
		Star = "star",
	},
	VehicleKinds = {
		Default = "ride",
		MiningDrill = "pickaxe",
		Mole = "auto",
	},
	BackpackShapes = {
		Default = "backpack",
		Bucket = "sand",
		Box = "crate",
		Cart = "shop",
		Vehicle = "ride",
		Orb = "gem",
	},
	TreasureShapes = {
		Default = "treasure",
		Coin = "coins",
		Shell = "shell",
		Chest = "treasure",
		Gem = "gem",
		Egg = "eggs",
		Shard = "tokens",
		Box = "crate",
		Crown = "trophy",
	},
	BoostKinds = {
		Default = "multiplier",
		Sand = "boost_sand",
		Luck = "boost_luck",
		Coins = "boost_coins",
		Speed = "boost_speed",
	},
	Events = {
		Default = "star",
		HighTide = "high_tide",
		GoldenHour = "golden_hour",
	},
}

-- Atlas offset for an icon name ("coins") or a UI/Icons.luau key ("Coins"); nil if unknown.
local function Resolve(key: string): Vector2?
	local direct = Icons[key]
	if direct then
		return direct
	end
	local alias = Aliases[key]
	return if alias then Icons[alias] else nil
end

-- Atlas offset for a grouped Icons.luau entry, e.g. GroupOffset("PetShapes", "Crab").
local function GroupOffset(group: string, key: string): Vector2?
	local g = Groups[group]
	if not g then
		return nil
	end
	local name = g[key] or g.Default
	return if name then Icons[name] else nil
end

return {
	AssetId = ASSET_ID,
	CellSize = 128,
	Icons = Icons,
	Aliases = Aliases,
	Groups = Groups,
	Resolve = Resolve,
	GroupOffset = GroupOffset,
}

```

## src/shared/Config/init.luau

Original SHA-256: `17ea916112a67808b721cea82f1dcf5415301e4b0189304ed9a838606e01773e`

```lua
--!strict
--[[
	Config — single entry point for ALL balance & presentation data.
	ReplicatedStorage.Shared.Config (owner: Game design). Read-only at runtime: never mutate.

	Fields:   Layers, Shovels, Backpacks, Pets, Eggs, Treasures, Rarities, Rebirths, Quests,
	          DailyRewards, Codes, Monetization, Boosts, Events, Sounds, Theme
	Helpers:  see function list below; all lookups are O(1) via maps built at require time.

	Depth unit: studs below the beach surface (positive). 1 stud = 1 "meter" in the UI.
	Sand -> Coins at SELL_RATE. Sand per dig =
	    layer.SandValue * shovel.SandMultiplier * RebirthMultiplier * PetMultiplier
	    * (pass/premium/group/friend/boost/event multipliers, all multiplicative)
	Capacity = backpack.Capacity * RebirthMultiplier * (MegaBackpack ? 2 : 1)
]]

local Types = require(script.Parent.Types)

local Layers = require(script.Layers)
local Shovels = require(script.Shovels)
local Backpacks = require(script.Backpacks)
local Pets = require(script.Pets)
local Eggs = require(script.Eggs)
local Treasures = require(script.Treasures)
local Rarities = require(script.Rarities)
local Rebirths = require(script.Rebirths)
local Quests = require(script.Quests)
local DailyRewards = require(script.DailyRewards)
local Codes = require(script.Codes)
local Badges = require(script.Badges)
local Monetization = require(script.Monetization)
local Boosts = require(script.Boosts)
local Events = require(script.Events)
local Sounds = require(script.Sounds)
local Theme = require(script.Theme)
local Heat = require(script.Heat)
local Shades = require(script.Shades)
local Consumables = require(script.Consumables)
local Ride = require(script.Ride) -- v2.1 ride-on excavator tuning (Ride agent)
local RebirthPerks = require(script.RebirthPerks) -- v2.2 rebirth token perk shop (Rebirth agent)
local Titles = require(script.Titles) -- v2.2 nameplate titles (Status & Social agent)
local Social = require(script.Social) -- v2.2 announcements / leaderboard scopes / server goal
local Discovery = require(script.Discovery) -- v3 buried finds / detector / excavation (Discovery agent)

local TOTAL_DEPTH = Layers[#Layers].DepthEnd

local Config = {
	-- Data ---------------------------------------------------------------------------------
	Layers = Layers,
	Shovels = Shovels,
	Backpacks = Backpacks,
	Pets = Pets,
	Eggs = Eggs,
	Treasures = Treasures,
	Rarities = Rarities,
	Rebirths = Rebirths,
	Quests = Quests,
	DailyRewards = DailyRewards,
	Codes = Codes,
	Badges = Badges,
	Monetization = Monetization,
	Boosts = Boosts,
	Events = Events,
	Sounds = Sounds,
	Theme = Theme,
	Heat = Heat,
	Shades = Shades,
	Consumables = Consumables,
	Ride = Ride,
	RebirthPerks = RebirthPerks,
	Titles = Titles,
	Social = Social,
	Discovery = Discovery,

	-- World --------------------------------------------------------------------------------
	-- One shared dig zone along the shoreline (World.GetDigZone); no plots.
	MAX_PLAYERS = 16, -- OWNER: set Game Settings > Places > Max Players to this
	TOTAL_DEPTH = TOTAL_DEPTH, -- studs from surface to the bottom of The Core
	-- Surface is high up so the bottom of the hole (SURFACE_Y - TOTAL_DEPTH = 24) stays well above
	-- Workspace.FallenPartsDestroyHeight (-500). Terrain must not be generated below Y = 0.
	SURFACE_Y = 1024,
	STUDS_PER_METER = 1,
	-- The tide refills a dug 8x8 column once no player was within TIDE_CLEAR_RADIUS studs
	-- (horizontally) for this long. High Tide smooths every hole at once.
	TIDE_REFILL_SECONDS = 240,
	TIDE_CLEAR_RADIUS = 12,

	-- Digging ------------------------------------------------------------------------------
	REACH = 20, -- max studs from HumanoidRootPart to the dig point
	COOLDOWN_LENIENCY = 0.85, -- server accepts a dig after Cooldown * this (latency slack)
	SELL_RATE = 1, -- coins per sand
	MAX_TREASURE_CHANCE = 0.5, -- cap after luck multipliers
	-- Collection bonus: +2% sand for every layer whose treasures are ALL in PlayerData.Index
	-- (computed from Index, nothing extra persisted). Max 15 layers = +30%.
	INDEX_LAYER_BONUS = 0.02,

	-- Pets ---------------------------------------------------------------------------------
	-- Base equip slots (PlayerData.PetSlots default). Passes add GamePasses[*].ExtraPetSlots:
	-- ExtraPets +2, AutoDig +1 (Stats.GetPetSlots).
	MAX_EQUIPPED_PETS = 3,
	PET_INVENTORY_LIMIT = 200,
	TRIPLE_HATCH_COUNT = 3,
	-- v2.2 hatch pity + duplicate fusion (docs/design/Companions.md "Pity and Golden pets").
	PITY_MIN_RARITY_ORDER = 3, -- "Rare or better" (RarityDef.Order); EggDef.PityAt per egg
	GOLDEN_FUSE_COUNT = 5, -- identical non-golden copies fused into one Golden pet
	GOLDEN_SAND_BONUS = 1.5, -- a Golden pet's sand bonus (Multiplier - 1) is x1.5
	GOLDEN_DIG_SPEED = 1.25, -- a Golden digging pet digs 1.25x as often (Interval / 1.25)

	-- Social -------------------------------------------------------------------------------
	GROUP_ID = 0, -- OWNER: paste the Roblox group id; members get GROUP_SAND_MULTIPLIER
	GROUP_SAND_MULTIPLIER = 1.1,
	FRIEND_BONUS_PER_FRIEND = 0.05, -- +5% sand per friend in the same server...
	FRIEND_BONUS_MAX = 0.2, -- ...up to +20%
	LEADERBOARD_SIZE = 50,
	LEADERBOARD_REFRESH_SECONDS = 60,

	-- Retention ----------------------------------------------------------------------------
	DAILY_COOLDOWN_SECONDS = 20 * 3600,
	DAILY_STREAK_GRACE_SECONDS = 48 * 3600,

	-- Persistence --------------------------------------------------------------------------
	DATASTORE_NAME = "PlayerData_v1",
	LEADERBOARD_COINS_STORE = "Leaderboard_Coins",
	LEADERBOARD_DEPTH_STORE = "Leaderboard_Depth",
	-- 2: v2.1 converts data.Diggers into vehicle pets; 3: v3 moves unsold Treasures into Finds
	-- (DataService migrations)
	DATA_VERSION = 3,
	AUTOSAVE_SECONDS = 120,
	SESSION_LOCK_SECONDS = 1800,

	-- Onboarding (FTUE) --------------------------------------------------------------------
	-- Complete events: "AtSand", "Dig", "BackpackFull", "Sell", "BuyShovel", "HatchEgg".
	-- Target "Sand" = the nearest point of the dig zone.
	TUTORIAL_STEPS = {
		{ Id = "go_sand", Text = "Follow the arrow to the sand!", Target = "Sand", Complete = "AtSand" },
		{ Id = "first_dig", Text = "Tap the sand to DIG!", Target = "Sand", Complete = "Dig" },
		{ Id = "fill_up", Text = "Keep digging until your bucket is full!", Complete = "BackpackFull" },
		{ Id = "sell", Text = "Bucket full! Run to the SELL stand.", Target = "SellZone", Complete = "Sell" },
		{ Id = "shop", Text = "Buy a better shovel to dig deeper!", Target = "ShovelShop", Complete = "BuyShovel" },
		{ Id = "dig_deeper", Text = "New shovel! Dig DOWN into a new layer!", Target = "Sand", Complete = "NewLayer" },
		{ Id = "egg", Text = "Hatch a pet - pets give you more sand!", Target = "EggShop", Complete = "HatchEgg" },
	} :: { Types.TutorialStep },
}

-- Lookup maps --------------------------------------------------------------------------------

local function indexById<T>(list: { T }, getId: (T) -> string): ({ [string]: T }, { [string]: number })
	local byId: { [string]: T } = {}
	local indexOf: { [string]: number } = {}
	for i, item in list do
		local id = getId(item)
		assert(byId[id] == nil, "Config: duplicate id " .. id)
		byId[id] = item
		indexOf[id] = i
	end
	return byId, indexOf
end

local shovelById, shovelIndex = indexById(Shovels, function(s: Types.ShovelDef)
	return s.Id
end)
local backpackById, backpackIndex = indexById(Backpacks, function(b: Types.BackpackDef)
	return b.Id
end)
local petById = indexById(Pets, function(p: Types.PetDef)
	return p.Id
end)
local eggById = indexById(Eggs, function(e: Types.EggDef)
	return e.Id
end)
local treasureById = indexById(Treasures, function(t: Types.TreasureDef)
	return t.Id
end)
local rarityByName = indexById(Rarities, function(r: Types.RarityDef)
	return r.Name
end)
local questById = indexById(Quests, function(q: Types.QuestDef)
	return q.Id
end)
local boostById = indexById(Boosts, function(b: Types.BoostDef)
	return b.Id
end)
local eventById = indexById(Events, function(e: Types.EventDef)
	return e.Id
end)
local codeByCode = indexById(Codes, function(c: Types.CodeDef)
	return string.upper(c.Code)
end)

-- Helpers ------------------------------------------------------------------------------------

function Config.GetShovel(id: string): Types.ShovelDef?
	return shovelById[id]
end

function Config.GetShovelIndex(id: string): number?
	return shovelIndex[id]
end

function Config.GetBackpack(id: string): Types.BackpackDef?
	return backpackById[id]
end

function Config.GetBackpackIndex(id: string): number?
	return backpackIndex[id]
end

function Config.GetPet(id: string): Types.PetDef?
	return petById[id]
end

function Config.GetEgg(id: string): Types.EggDef?
	return eggById[id]
end

function Config.GetTreasure(id: string): Types.TreasureDef?
	return treasureById[id]
end

function Config.GetRarity(name: string): Types.RarityDef?
	return rarityByName[name]
end

function Config.GetQuest(id: string): Types.QuestDef?
	return questById[id]
end

function Config.GetBoost(id: string): Types.BoostDef?
	return boostById[id]
end

function Config.GetEvent(id: string): Types.EventDef?
	return eventById[id]
end

-- Case-insensitive, whitespace-trimmed. Returns nil for unknown codes (does NOT check Enabled/Expires).
function Config.GetCode(code: string): Types.CodeDef?
	local normalized = string.upper((string.gsub(code, "%s", "")))
	return codeByCode[normalized]
end

-- Index (1..#Layers) of the layer at `depth` studs below the surface. Clamped to the range.
function Config.GetLayerIndexAtDepth(depth: number): number
	if depth < 0 then
		return 1
	end
	for i, layer in Layers do
		if depth < layer.DepthEnd then
			return i
		end
	end
	return #Layers
end

function Config.GetLayerAtDepth(depth: number): Types.LayerDef
	return Layers[Config.GetLayerIndexAtDepth(depth)]
end

-- Deepest layer index this shovel power can dig (layers with Hardness <= power).
function Config.GetMaxLayerIndexForPower(power: number): number
	local best = 1
	for i, layer in Layers do
		if layer.Hardness <= power then
			best = i
		end
	end
	return best
end

function Config.DepthToMeters(depth: number): number
	return math.floor(math.max(depth, 0) / Config.STUDS_PER_METER)
end

-- Coins for the NEXT rebirth when the player has `rebirths` rebirths.
function Config.RebirthCost(rebirths: number): number
	return Rebirths.Cost(rebirths)
end

function Config.RebirthMultiplier(rebirths: number): number
	return Rebirths.Multiplier(rebirths)
end

function Config.RebirthTokens(rebirths: number): number
	return Rebirths.Tokens(rebirths)
end

-- Additive pet bonus: 1 + sum(Multiplier - 1). Unknown ids are ignored.
-- v2.2: golden[i] = true marks petIds[i] as a Golden pet (bonus x GOLDEN_SAND_BONUS).
function Config.PetMultiplier(petIds: { string }, golden: { [number]: boolean }?): number
	local total = 1
	for i, id in petIds do
		local pet = petById[id]
		if pet then
			local bonus = pet.Multiplier - 1
			if golden and golden[i] then
				bonus *= Config.GOLDEN_SAND_BONUS
			end
			total += bonus
		end
	end
	return total
end

-- v2.2: one pet's own multiplier (1 + bonus), Golden included. Unknown id -> 1.
function Config.PetEffectiveMultiplier(petId: string, golden: boolean?): number
	return Config.PetMultiplier({ petId }, { golden == true })
end

-- Flat Coins + ScaledCoins * RewardScale of the layer at maxDepth. Rounded down.
function Config.ResolveCoins(reward: Types.Reward, maxDepth: number): number
	local coins = reward.Coins or 0
	if reward.ScaledCoins then
		coins += reward.ScaledCoins * Config.GetLayerAtDepth(maxDepth).RewardScale
	end
	return math.floor(coins)
end

function Config.IsEggUnlocked(eggId: string, maxDepth: number): boolean
	local egg = eggById[eggId]
	if not egg then
		return false
	end
	local layer = Layers[egg.UnlockLayer]
	return layer ~= nil and maxDepth >= layer.DepthStart
end

-- Reward row for a streak value (1-based, cycles every #DailyRewards days).
function Config.GetDailyReward(streak: number): Types.DailyRewardDef
	local index = ((math.max(streak, 1) - 1) % #DailyRewards) + 1
	return DailyRewards[index]
end

-- Events active at unix time `now` (defaults to os.time()).
function Config.GetActiveEvents(now: number?): { Types.EventDef }
	local t = now or os.time()
	local active = {}
	for _, event in Events do
		if (t + event.OffsetSeconds) % event.IntervalSeconds < event.DurationSeconds then
			table.insert(active, event)
		end
	end
	return active
end

-- Seconds until the event next starts (0 if active now).
function Config.GetSecondsUntilEvent(eventId: string, now: number?): number
	local event = eventById[eventId]
	if not event then
		return math.huge
	end
	local phase = ((now or os.time()) + event.OffsetSeconds) % event.IntervalSeconds
	if phase < event.DurationSeconds then
		return 0
	end
	return event.IntervalSeconds - phase
end

function Config.GetGamePassKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, pass in Monetization.GamePasses do
		if pass.Id == id then
			return key
		end
	end
	return nil
end

function Config.GetProductKeyById(id: number): string?
	if id == 0 then
		return nil
	end
	for key, product in Monetization.Products do
		if product.Id == id then
			return key
		end
	end
	return nil
end

-- Companions (v2.1) ---------------------------------------------------------------------------

-- Construction Crates are eggs with Kind = "Crate" (they hatch vehicle pets).
function Config.IsCrate(eggId: string): boolean
	local egg = eggById[eggId]
	return egg ~= nil and egg.Kind == "Crate"
end

-- The pet's dig ability (vehicles from crates, a few creatures), or nil.
function Config.GetPetDig(petId: string): Types.PetDigDef?
	local pet = petById[petId]
	return if pet then pet.Dig else nil
end

-- v2.2: seconds between digs for this pet; Golden pets dig GOLDEN_DIG_SPEED x as often.
function Config.GetPetDigInterval(petId: string, golden: boolean?): number?
	local dig = Config.GetPetDig(petId)
	if not dig then
		return nil
	end
	return (dig :: Types.PetDigDef).Interval / (if golden then Config.GOLDEN_DIG_SPEED else 1)
end

-- Compliance (v2.2) -----------------------------------------------------------------------------

-- Is this pass / product a paid random item, a paid luck modifier or currency that buys random
-- items (Monetization PaidRandom)? Those are hidden and refused for PolicyService-restricted
-- players (ArePaidRandomItemsRestricted). kind: "GamePass" | "Product".
function Config.IsPaidRandom(kind: string, key: string): boolean
	if kind == "GamePass" then
		local pass = Monetization.GamePasses[key]
		return pass ~= nil and pass.PaidRandom == true
	elseif kind == "Product" then
		local product = Monetization.Products[key]
		return product ~= nil and product.PaidRandom == true
	end
	return false
end

-- Ride (v2.1, Ride agent) ----------------------------------------------------------------------

-- The best rideable pet (PetDef.Rideable) among an inventory (PlayerData.Pets), or nil. Scans
-- Config.Pets (not the id map) so every def counts. Best = highest Dig.Power, then SandMultiplier.
function Config.FindRideablePet(pets: { [string]: Types.PetInstance }?): Types.PetDef?
	if not pets then
		return nil
	end
	local owned: { [string]: boolean } = {}
	for _, pet in pets :: { [string]: Types.PetInstance } do
		if type(pet) == "table" and type(pet.Id) == "string" then
			owned[pet.Id] = true
		end
	end
	local best: Types.PetDef? = nil
	for _, def in Pets do
		if def.Rideable == true and owned[def.Id] then
			local current = best
			local power = if def.Dig then def.Dig.Power else 0
			local sand = if def.Dig then def.Dig.SandMultiplier else 0
			local bestPower = if current and current.Dig then current.Dig.Power else -1
			local bestSand = if current and current.Dig then current.Dig.SandMultiplier else -1
			if current == nil or power > bestPower or (power == bestPower and sand > bestSand) then
				best = def
			end
		end
	end
	return best
end

-- Survival (v2) ---------------------------------------------------------------------------------

local shadeById, shadeIndex = indexById(Shades, function(d: Types.ShadeDef)
	return d.Id
end)
local consumableById = indexById(Consumables, function(d: Types.ConsumableDef)
	return d.Id
end)

function Config.GetShade(id: string): Types.ShadeDef?
	return shadeById[id]
end

function Config.GetShadeIndex(id: string): number?
	return shadeIndex[id]
end

function Config.GetConsumable(id: string): Types.ConsumableDef?
	return consumableById[id]
end

-- Number of layers whose every treasure is in `index` (collection book completion).
function Config.CountCompletedIndexLayers(index: { [string]: boolean }): number
	local complete = 0
	for _, layer in Layers do
		local all = true
		for _, entry in layer.LootTable do
			if not index[entry.TreasureId] then
				all = false
				break
			end
		end
		if all then
			complete += 1
		end
	end
	return complete
end

-- Status & Social (v2.2) ------------------------------------------------------------------------

-- Nameplate title for a layer index (clamped to 1..#Layers): (title, colour).
function Config.GetTitle(layerIndex: number): (string, Color3)
	local index = math.clamp(math.floor(layerIndex), 1, #Titles)
	local def = Titles[index]
	return def.Title, def.Color or Layers[index].Color
end

-- Server dig goal (sand) for a server whose players have these MaxDepth values. See Config/Social.
function Config.ServerGoalTarget(maxDepths: { number }): number
	local goal = Social.ServerGoal
	local total = 0
	for _, depth in maxDepths do
		local layer = Config.GetLayerAtDepth(depth)
		total += math.max(goal.PerPlayerSand, layer.RewardScale * goal.DigSeconds)
	end
	total = math.max(total, goal.MinSand)
	return math.ceil(total / goal.Round) * goal.Round
end

-- Fresh default save for a brand-new player.
function Config.NewPlayerData(): Types.PlayerData
	local firstShovel = Shovels[1].Id
	local firstBackpack = Backpacks[1].Id
	return {
		Coins = 0,
		Sand = 0,
		TotalSandDug = 0,
		Rebirths = 0,
		RebirthTokens = 0,
		MaxDepth = 0,
		Shovel = firstShovel,
		OwnedShovels = { [firstShovel] = true },
		Backpack = firstBackpack,
		OwnedBackpacks = { [firstBackpack] = true },
		Pets = {},
		PetSlots = Config.MAX_EQUIPPED_PETS,
		Treasures = {},
		Finds = {}, -- v3 discovery
		FindVariants = {}, -- v3 discovery
		Index = {},
		DailyStreak = 0,
		LastDailyClaim = 0,
		Quests = {},
		RedeemedCodes = {},
		Settings = {},
		Boosts = {},
		Consumables = {},
		OwnedShades = {},
		Diggers = {},
		LastOnline = 0,
		Pity = {},
		RebirthPerks = {},
		PlayTime = 0,
		FirstJoin = os.time(),
		Version = Config.DATA_VERSION,
	}
end

-- Sanity checks on require (cheap; catches typos in ids when editing balance data) ----------

do
	for i, layer in Layers do
		assert(layer.DepthEnd > layer.DepthStart, "Config: bad depth band in layer " .. layer.Id)
		if i > 1 then
			assert(layer.DepthStart == Layers[i - 1].DepthEnd, "Config: gap before layer " .. layer.Id)
		end
		for _, entry in layer.LootTable do
			assert(treasureById[entry.TreasureId], "Config: unknown treasure " .. entry.TreasureId)
		end
	end
	for _, egg in Eggs do
		for _, entry in egg.Pets do
			assert(petById[entry.PetId], "Config: unknown pet " .. entry.PetId .. " in egg " .. egg.Id)
		end
		if egg.ProductKey then
			assert(Monetization.Products[egg.ProductKey], "Config: unknown product key " .. egg.ProductKey)
		end
		if egg.PityAt then
			local hasRarePlus = false
			for _, entry in egg.Pets do
				local rarity = rarityByName[petById[entry.PetId].Rarity]
				hasRarePlus = hasRarePlus or rarity.Order >= Config.PITY_MIN_RARITY_ORDER
			end
			assert(egg.PityAt >= 1 and hasRarePlus, "Config: PityAt needs a Rare+ pet in egg " .. egg.Id)
		end
	end
	for _, treasure in Treasures do
		assert(rarityByName[treasure.Rarity], "Config: unknown rarity on " .. treasure.Id)
		assert(not string.find(treasure.Id, "[|/]"), "Config: treasure ids may not contain | or / " .. treasure.Id)
		if treasure.Rarity == "Relic" then
			assert((treasure.ScaledValue or 0) > 0, "Config: Relic without ScaledValue " .. treasure.Id)
		end
	end
	assert(#Discovery.DENSITY == #Layers, "Config: one Discovery.DENSITY per layer")
	for _, group in { Discovery.SIZES, Discovery.MATERIALS } do
		local total = 0
		for _, v in group do
			total += v.Weight
		end
		assert(math.abs(total - 100) < 1e-6, "Config: Discovery variant weights must sum to 100")
	end
	-- v2.3 paid randomness rules (owner decision, docs/CHANGELOG.md v2.3): no Robux item sells
	-- a random outcome or a luck modifier.
	for _, egg in Eggs do
		assert(egg.Currency ~= "Robux" and egg.ProductKey == nil, "Config: eggs are never sold for Robux " .. egg.Id)
	end
	for key, pass in Monetization.GamePasses do
		assert(pass.LuckMultiplier == nil, "Config: no paid luck (pass " .. key .. ")")
	end
	for key, product in Monetization.Products do
		local boostDef: Types.BoostDef? = nil
		for _, b in Boosts do
			if b.Id == product.Grant.Boost then
				boostDef = b
			end
		end
		assert(product.Grant.Egg == nil, "Config: no paid eggs (product " .. key .. ")")
		assert(not (boostDef and boostDef.Kind == "Luck"), "Config: no paid luck (product " .. key .. ")")
	end
	assert(#Titles == #Layers, "Config: one title per layer")
	for i, title in Titles do
		assert(title.LayerId == Layers[i].Id, "Config: title " .. i .. " is not for layer " .. Layers[i].Id)
	end
	for _, pet in Pets do
		local dig = pet.Dig
		if dig then
			assert(dig.Power > 0 and dig.Interval > 0 and dig.Radius > 0, "Config: bad Dig stats on " .. pet.Id)
		end
	end
	for _, egg in Eggs do
		if egg.Kind == "Crate" then
			for _, entry in egg.Pets do
				assert(petById[entry.PetId].Dig, "Config: crate pet without Dig " .. entry.PetId)
			end
		end
	end
end

return Config

```

## src/shared/Config/Layers.luau

Original SHA-256: `45ff3cda82a268ccbf972d8905008a5f8f478b0083777f5dc3e2a8242c4621b0`

```lua
--!strict
--[[
	Layers — the hole, top to bottom. Ordered array; index 1 is the surface.
	Depths are studs below the beach surface. Total depth = 1000 studs ("1,000 m to the Core",
	Config.STUDS_PER_METER = 1).

	Rules:
	- Each layer uses a UNIQUE terrain Material because Terrain:SetMaterialColor is global per
	  material. The map may additionally use Water, Grass, LeafyGrass, Snow, Concrete, Asphalt,
	  Cobblestone for scenery, and Sand only with the Dry Sand colour.
	- Hardness gates progress: equipped shovel Power >= Hardness (see Shovels.luau, 1:1 ladder).
	- SandValue is sand per dig before multipliers; sand sells 1:1 for Coins.
	- RewardScale ~= coins/second a typical (un-rebirthed) player earns here; ScaledCoins rewards
	  are "seconds of income" multiplied by this.
	- TreasureChance is per successful dig; Luck multiplies it (cap 50%) and multiplies the
	  weight of every non-Common entry.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Layers: { Types.LayerDef } = {
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
}

return Layers

```

## src/shared/Config/Monetization.luau

Original SHA-256: `c39f69d8b962f5492e11b59cc9d585d9fd478971742d904867a964710b4f3cd4`

```lua
--!strict
--[[
	Monetization — game passes, developer products, Premium perks.

	==========================================================================================
	  OWNER ACTION REQUIRED: every `Id = 0` below is a PLACEHOLDER.
	  1. Publish the experience, then open Creator Hub -> Creations -> (this experience) ->
	     Monetization -> Passes: create one pass per entry in GamePasses (name, icon, price).
	     Monetization -> Developer Products: create one product per entry in Products.
	  2. Copy each numeric id from Creator Hub and paste it into the matching `Id = ...` field.
	  3. Republish. While an Id is 0 the server must treat the pass as NOT owned and the shop
	     must hide / disable the buy button (prompting id 0 errors).
	  Prices are suggestions in Robux; the price set in Creator Hub is what players pay. Once an
	  Id is set, the store reads the live price (MarketplaceService:GetProductInfo, see
	  PurchaseController.GetPrice) and only falls back to `Price` below when that fails.
	  v2.3: suggested prices moved up to the competitor band (comparable passes 175-750 R$).
	  After launch, turn on Roblox Managed Pricing (Creator Hub -> Monetization) for the dev
	  products so Roblox tunes regional prices; passes keep the prices set here.
	==========================================================================================

	Pass effects are expressed as optional multiplier fields so the server can fold them in
	generically. Keys are stable API: server and UI reference passes by key, e.g.
	Config.Monetization.GamePasses.SellAnywhere.
	Design rule: everything a pass gives can be approximated by playing (boosts from quests,
	pets, rebirths). Passes make it faster/comfier, never exclusive power walls.

	v2.2 compliance:
	- PaidRandom = true marks a currency that buys random outcomes (Coins buy eggs and crates;
	  Skip Rebirth grants Rebirth Tokens, which buy the Rebirth and Golden Eggs). Players whose
	  PolicyService:GetPolicyInfoForPlayerAsync says ArePaidRandomItemsRestricted never see them
	  and the server refuses to prompt them (Services/PolicyService). Completed purchases are
	  always honoured. Every random outcome shows its true odds incl. luck (Stats.GetHatchOdds).
	- The Cooler Pack product was removed: it sold relief from heat friction we designed.

	v2.3 paid randomness simplification (owner decision):
	- No Robux item buys a random outcome or a luck modifier any more. Removed: the Golden Egg and
	  3 Golden Eggs products (the Golden Egg now costs Rebirth Tokens, Config/Eggs), the 2x Luck
	  (15 min) product and the Lucky Shovel pass. VIP lost its +25% luck and gained +10% sell
	  coins (CoinMultiplier) instead. Turbo Shovel (+25% dig speed) takes the Lucky pass's slot.
	- Luck stays earnable for free: Luck events, the Lucky Digger perk, 2x Luck from quests,
	  daily rewards and codes. Config's require-time checks reject any pass with LuckMultiplier,
	  any product that grants luck or an egg, and any egg sold for Robux.
	- Paid random items now exist only indirectly: coin packs and Skip Rebirth buy currency
	  that can buy eggs, so they stay PaidRandom (hidden for policy-restricted players).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Monetization: Types.MonetizationConfig = {
	GamePasses = {
		VIP = {
			Id = 2018534367,
			Name = "VIP",
			Price = 349,
			-- v2.3: the +25% luck was removed (luck sold for Robux is a paid probability modifier);
			-- +10% sell coins replaces it. "2 shades" = Heat.ShadeSlotsVip (SurvivalShades).
			Description = "+25% sand, +10% coins when you sell, place 2 shades at once and a gold VIP tag on your nameplate.",
			Color = rgb(255, 200, 40),
			SandMultiplier = 1.25,
			CoinMultiplier = 1.1,
		},
		DoubleSand = {
			Id = 2019326377,
			Name = "2x Sand",
			Price = 399,
			Description = "Double sand from every single dig. Forever!",
			Color = rgb(255, 170, 40),
			SandMultiplier = 2,
		},
		SellAnywhere = {
			Id = 2019386387,
			Name = "Sell Anywhere",
			Price = 249,
			-- v2.2: also earnable for free with the Sell Anywhere rebirth perk (Config.RebirthPerks)
			Description = "Sell your sand from anywhere with one tap - even at the bottom of the hole. Get it now, or unlock it for free later with Rebirth Perks!",
			Color = rgb(60, 200, 110),
		},
		AutoDig = {
			Id = 2017796369,
			Name = "Auto Dig",
			Price = 299,
			Description = "+1 Pet slot & auto-swing: your character keeps digging by itself.",
			Color = rgb(60, 170, 255),
			ExtraPetSlots = 1, -- v2.1: was +1 digger slot (diggers are pets now)
		},
		-- v2.3: replaces the Lucky Shovel pass (removed: paid luck). Deterministic speed only.
		FastDig = {
			Id = 2019320389,
			Name = "Turbo Shovel",
			Price = 249,
			Description = "Dig 25% faster with every shovel. Forever!",
			Color = rgb(60, 190, 255),
			SpeedMultiplier = 1.25,
		},
		TripleHatch = {
			Id = 2019608364,
			Name = "Triple Hatch",
			Price = 249,
			Description = "Hatch 3 eggs at once.",
			Color = rgb(255, 120, 200),
		},
		ExtraPets = {
			Id = 2018012384,
			Name = "+2 Pet Slots",
			Price = 349,
			Description = "Equip 2 more pets at the same time.",
			Color = rgb(180, 100, 255),
			ExtraPetSlots = 2,
		},
		MegaBackpack = {
			Id = 2017934384,
			Name = "Mega Backpack",
			Price = 299,
			Description = "2x backpack capacity on every backpack. Fewer trips, more digging!",
			Color = rgb(255, 120, 60),
			CapacityMultiplier = 2,
		},
	},

	Products = {
		CoinsSmall = {
			Id = 3717251713,
			Name = "Pile of Coins",
			Price = 49,
			Description = "5 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 300, Coins = 500 },
			PaidRandom = true,
		},
		CoinsMedium = {
			Id = 3717251822,
			Name = "Bag of Coins",
			Price = 149,
			Description = "25 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 1500, Coins = 2500 },
			PaidRandom = true,
		},
		CoinsLarge = {
			Id = 3717251873,
			Name = "Chest of Coins",
			Price = 399,
			Description = "2 hours worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 7200, Coins = 12000 },
			PaidRandom = true,
		},
		CoinsHuge = {
			Id = 3717251948,
			Name = "Sunken Ship of Coins",
			Price = 999,
			Description = "6 hours worth of coins at your deepest layer!",
			Grant = { ScaledCoins = 21600, Coins = 40000 },
			PaidRandom = true,
		},
		SandBoost15 = {
			Id = 3717252005,
			Name = "2x Sand (15 min)",
			Price = 49,
			Description = "Double sand for 15 minutes. Stacks time.",
			Grant = { Boost = "SandBoost", BoostSeconds = 900 },
		},
		SkipRebirth = {
			Id = 3717252052,
			Name = "Skip Rebirth",
			Price = 199,
			Description = "Rebirth right now without paying the coin cost.",
			Grant = { Rebirth = true },
			PaidRandom = true,
		},
	},

	-- Roblox Premium: payouts are driven by Premium members' engagement time, so we give them a
	-- small, visible thank-you (no paywall). Server listens to Players.PlayerMembershipChanged.
	Premium = {
		SandMultiplier = 1.1,
		DailyRewardMultiplier = 1.5,
		ChatTag = "[PREMIUM]",
	},
}

return Monetization

```

## src/shared/Config/Pets.luau

Original SHA-256: `57c3c5e990b3e96adf0e23610dc5cfbc15725d4c3cea128a62e58e91ff515f5b`

```lua
--!strict
--[[
	Pets — follow you and multiply sand. Bonuses combine ADDITIVELY:
	total = 1 + sum(Multiplier - 1) over equipped pets (Config.PetMultiplier).
	So three 1.5x pets = 2.5x, not 3.375x. Keeps late game from exploding.
	Exclusive pets are not in any egg (daily streak / codes / events).

	v2.1 companions (docs/design/Companions.md):
	- Dig = Types.PetDigDef: the pet also digs its own spot on a ring around the owner
	  (Services/PetDigService). Power gates layers like a shovel, SandMultiplier replaces the
	  shovel factor for that dig (every other multiplier still applies), Interval = seconds per dig.
	  Each digging pet makes ~8-20% of the active sand/second of the shovel with the same Power, so
	  even 6 slots of the best diggers stay under active shovel digging.
	- Vehicle pets (VehicleKind = a Models/Diggers builder) hatch from Construction Crates
	  (Config/Eggs.luau, Kind = "Crate"). Their sand Multiplier is smaller than creature pets of
	  the same tier: you trade multiplier for digging.
	- Rideable = true: the player can ride it (Ride agent, Services/RideService).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Pets: { Types.PetDef } = {
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},

	-- v2.1 vehicle pets (Construction Crates). Dig % = share of the same-Power shovel's active
	-- sand/second (see docs/design/Companions.md). Ex-Garage diggers keep their ids (save migration).
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
}

return Pets

```

## src/shared/Config/Quests.luau

Original SHA-256: `1f939191ac12234c557fe0c53608c472bca1d5dd6aec7b1a2b4463f746f3953a`

```lua
--!strict
--[[
	Quests — Daily quests reset at 00:00 UTC (QuestProgress.Day != today -> reset progress/claim).
	Once quests are milestones (claim once, ever).
	Rewards use ScaledCoins ("seconds of income" x RewardScale of the player's deepest layer) so
	they stay worth it at every stage. Resolve with Config.ResolveCoins(reward, data.MaxDepth).
	Progress hooks (server): Dig -> DigTimes; Sell -> SellTimes; treasure -> FindTreasures /
	FindRarity (Rarity or rarer); hatch -> HatchEggs (+count); every minute -> PlayMinutes;
	shovel/backpack purchase -> BuyUpgrade; MaxDepth -> ReachDepth (set Progress = MaxDepth);
	rebirth -> Rebirth.
]]

local Types = require(script.Parent.Parent.Types)

local Quests: { Types.QuestDef } = {
	-- Daily ---------------------------------------------------------------------------------
	{
		Id = "daily_dig_100",
		Name = "Busy Beaver",
		Description = "Dig 100 times",
		Kind = "DigTimes",
		Target = 100,
		Reset = "Daily",
		Reward = { ScaledCoins = 60 },
	},
	{
		Id = "daily_dig_1000",
		Name = "Dig Machine",
		Description = "Dig 1,000 times",
		Kind = "DigTimes",
		Target = 1000,
		Reset = "Daily",
		Reward = { ScaledCoins = 240, Boost = "SandBoost", BoostSeconds = 600 },
	},
	{
		Id = "daily_sell_10",
		Name = "Sand Salesman",
		Description = "Sell your sand 10 times",
		Kind = "SellTimes",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120 },
	},
	{
		Id = "daily_treasure_10",
		Name = "Treasure Hunter",
		Description = "Find 10 treasures",
		Kind = "FindTreasures",
		Target = 10,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "LuckBoost", BoostSeconds = 600 },
	},
	{
		Id = "daily_rare_1",
		Name = "Lucky Find",
		Description = "Find a Rare (or better) treasure",
		Kind = "FindRarity",
		Target = 1,
		Rarity = "Rare",
		Reset = "Daily",
		Reward = { ScaledCoins = 180 },
	},
	{
		Id = "daily_hatch_5",
		Name = "Egg-cellent",
		Description = "Hatch 5 eggs",
		Kind = "HatchEggs",
		Target = 5,
		Reset = "Daily",
		Reward = { ScaledCoins = 150 },
	},
	{
		Id = "daily_play_20",
		Name = "Beach Day",
		Description = "Play for 20 minutes",
		Kind = "PlayMinutes",
		Target = 20,
		Reset = "Daily",
		Reward = { ScaledCoins = 120, Boost = "CoinBoost", BoostSeconds = 600 },
	},
	-- Milestones ----------------------------------------------------------------------------
	{
		Id = "reach_pirate_cove",
		Name = "Yo Ho Ho!",
		Description = "Reach the Pirate Cove (110m)",
		Kind = "ReachDepth",
		Target = 110,
		Reset = "Once",
		Reward = { Coins = 1500 },
	},
	{
		Id = "reach_fossil_bed",
		Name = "Jurassic Beach",
		Description = "Reach the Fossil Bed (200m)",
		Kind = "ReachDepth",
		Target = 200,
		Reset = "Once",
		Reward = { Coins = 25000, Egg = "beach_egg", EggCount = 3 },
	},
	{
		Id = "reach_crystal_caverns",
		Name = "Shiny!",
		Description = "Reach the Crystal Caverns (330m)",
		Kind = "ReachDepth",
		Target = 330,
		Reset = "Once",
		Reward = { Coins = 250000, Boost = "LuckBoost", BoostSeconds = 900 },
	},
	{
		Id = "first_rebirth",
		Name = "Born Again Digger",
		Description = "Rebirth for the first time",
		Kind = "Rebirth",
		Target = 1,
		Reset = "Once",
		Reward = { RebirthTokens = 2 },
	},
	{
		Id = "reach_the_core",
		Name = "Journey to the Center",
		Description = "Reach THE CORE (885m)",
		Kind = "ReachDepth",
		Target = 885,
		Reset = "Once",
		Reward = { RebirthTokens = 10, ScaledCoins = 1800 },
	},
}

return Quests

```

## src/shared/Config/Rarities.luau

Original SHA-256: `e360cb3f646a1e3b515ad2a59c01826a89c84008c217db89231ab372db9a6f96`

```lua
--!strict
--[[
	Rarities — display data for treasure & pet rarities. Ordered array (Order 1..7; 7 = Relic, v3 finds only) plus the
	lookup helper Config.GetRarity(name). Gradient is meant for a UIGradient on rarity cards.
	Announce = broadcast a server-wide toast/chat message when anyone finds or hatches one.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Rarities: { Types.RarityDef } = {
	{
		Name = "Common",
		Order = 1,
		Color = rgb(200, 205, 215),
		Gradient = { rgb(230, 232, 238), rgb(170, 176, 190) },
		Announce = false,
	},
	{
		Name = "Uncommon",
		Order = 2,
		Color = rgb(90, 220, 100),
		Gradient = { rgb(150, 255, 150), rgb(40, 180, 80) },
		Announce = false,
	},
	{
		Name = "Rare",
		Order = 3,
		Color = rgb(60, 160, 255),
		Gradient = { rgb(120, 210, 255), rgb(30, 100, 240) },
		Announce = false,
	},
	{
		Name = "Epic",
		Order = 4,
		Color = rgb(180, 90, 255),
		Gradient = { rgb(220, 150, 255), rgb(130, 50, 230) },
		Announce = false,
	},
	{
		Name = "Legendary",
		Order = 5,
		Color = rgb(255, 190, 30),
		Gradient = { rgb(255, 235, 100), rgb(255, 130, 20) },
		Announce = true,
	},
	{
		Name = "Mythic",
		Order = 6,
		Color = rgb(255, 70, 140),
		Gradient = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(90, 220, 255), rgb(200, 90, 255) },
		Announce = true,
	},
	-- v3 discovery slice: above Mythic, only from buried finds (Config.Discovery.RELIC_CHANCE).
	{
		Name = "Relic",
		Order = 7,
		Color = rgb(120, 255, 230),
		Gradient = { rgb(255, 255, 255), rgb(120, 255, 230), rgb(255, 120, 230), rgb(255, 230, 120) },
		Announce = true,
	},
}

return Rarities

```

## src/shared/Config/RebirthPerks.luau

Original SHA-256: `e0ec198da96f6693f68cde005f5bbfb7d720751ccba4a419675b85a3737580ad`

```lua
--!strict
--[[
	RebirthPerks — permanent upgrades bought with Rebirth Tokens (docs/design/Rebirth.md).

	PlayerData.RebirthPerks = { [perkId] = level } (missing = level 0). Perks are never reset.
	Costs[i] = tokens for level i, so #Costs is the max level. Effect values per level live in
	`Levels` (index = level, 0 = not bought) so the UI can show "current -> next".

	Tuned against Config.Rebirths.Tokens (2, 2, 3, 3, 4, 4, 5 ... tokens per rebirth): the first
	rebirth (2 tokens) buys two level-1 perks (e.g. Head Start + Golden Touch); Sell Anywhere (5) is
	the big mid-term goal, reached around rebirth 3 (tools/sim/economy.luau: it is a ~3x speed-up).
	The Rebirth Egg (3 tokens) competes for the same tokens on purpose: a real choice each time.

	Effects (where they are applied):
	  HeadStart     start each rebirth with shovel Shovels[ShovelIndex] + Coins  (RebirthService)
	  KeepBackpack  keep your backpack on rebirth, up to Backpacks[KeepIndex]     (RebirthService)
	  SellAnywhere  same as the Sell Anywhere game pass                             (EconomyService)
	  DeepPockets   +x backpack capacity                                            (Stats.GetCapacity)
	  LuckyDigger   x treasure chance per dig (NOT egg luck: egg odds stay as shown) (Stats.GetTreasureChance)
	  LongNap       +hours offline cap and +offline efficiency                      (OfflineService)
	  PetDen        +pet equip slots                                                (Stats.GetPetSlots)
	  GoldenTouch   +x coins from selling (and offline earnings)                    (Stats.GetCoinFactors)
]]

export type PerkId =
	"HeadStart"
	| "KeepBackpack"
	| "SellAnywhere"
	| "DeepPockets"
	| "LuckyDigger"
	| "LongNap"
	| "PetDen"
	| "GoldenTouch"

export type PerkLevel = {
	ShovelIndex: number?, -- HeadStart
	Coins: number?, -- HeadStart
	KeepIndex: number?, -- KeepBackpack: highest backpack index kept
	Unlocked: boolean?, -- SellAnywhere
	Capacity: number?, -- DeepPockets: capacity factor
	TreasureChance: number?, -- LuckyDigger: treasure chance factor
	OfflineHours: number?, -- LongNap: extra cap hours
	OfflineEfficiency: number?, -- LongNap: extra efficiency (0..1)
	PetSlots: number?, -- PetDen
	Coin: number?, -- GoldenTouch: sell factor
}

export type PerkDef = {
	Id: PerkId,
	Name: string,
	Icon: string, -- AtlasIcon key ("atlas_name|emoji")
	Description: string,
	Costs: { number }, -- tokens for level 1, 2, ...
	Levels: { PerkLevel }, -- effect at level 1, 2, ... (same length as Costs)
	Order: number,
}

local Perks: { PerkDef } = {
	{
		Id = "SellAnywhere",
		Name = "Sell Anywhere",
		Icon = "sell|💸",
		Description = "Sell from anywhere with one tap, like the game pass.",
		Costs = { 5 },
		Levels = { { Unlocked = true } },
		Order = 1,
	},
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
	},
	{
		Id = "GoldenTouch",
		Name = "Golden Touch",
		Icon = "boost_coins|💰",
		Description = "More coins every time you sell.",
		Costs = { 1, 2, 3, 4, 5 },
		Levels = { { Coin = 1.1 }, { Coin = 1.2 }, { Coin = 1.3 }, { Coin = 1.4 }, { Coin = 1.5 } },
		Order = 3,
	},
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
	},
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
	},
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
	},
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
	},
	{
		Id = "PetDen",
		Name = "Pet Den",
		Icon = "pets|🐾",
		Description = "+1 pet slot.",
		Costs = { 3, 6 },
		Levels = { { PetSlots = 1 }, { PetSlots = 2 } },
		Order = 8,
	},
}

local byId: { [string]: PerkDef } = {}
for _, perk in Perks do
	assert(byId[perk.Id] == nil, "RebirthPerks: duplicate id " .. perk.Id)
	assert(#perk.Costs == #perk.Levels, "RebirthPerks: Costs/Levels length mismatch on " .. perk.Id)
	byId[perk.Id] = perk
end
table.sort(Perks, function(a: PerkDef, b: PerkDef): boolean
	return a.Order < b.Order
end)

local RebirthPerks = {
	List = Perks,
	-- Offline earnings (OfflineService): base values before Long Nap.
	OFFLINE_MIN_SECONDS = 5 * 60, -- shorter absences grant nothing
	OFFLINE_CAP_HOURS = 2,
	OFFLINE_EFFICIENCY = 0.4, -- pets dig at 40% without their owner around
	OFFLINE_MAX_GAP_SECONDS = 365 * 86400, -- larger gaps are treated as a broken clock: ignored
}

function RebirthPerks.Get(id: string): PerkDef?
	return byId[id]
end

function RebirthPerks.MaxLevel(id: string): number
	local def = byId[id]
	return if def then #def.Costs else 0
end

-- Level of a perk in a RebirthPerks table (tolerates nil / junk from old saves). Clamped.
function RebirthPerks.Level(perks: { [string]: number }?, id: string): number
	if type(perks) ~= "table" then
		return 0
	end
	local value = (perks :: any)[id]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, RebirthPerks.MaxLevel(id))
end

-- Token cost of the NEXT level, or nil when maxed / unknown.
function RebirthPerks.NextCost(perks: { [string]: number }?, id: string): number?
	local def = byId[id]
	if not def then
		return nil
	end
	return def.Costs[RebirthPerks.Level(perks, id) + 1]
end

-- Effect table at the current level (empty table at level 0).
function RebirthPerks.Effect(perks: { [string]: number }?, id: string): PerkLevel
	local def = byId[id]
	local level = RebirthPerks.Level(perks, id)
	if not def or level == 0 then
		return {}
	end
	return def.Levels[level]
end

-- Convenience accessors used by Stats / services / UI ------------------------------------------

function RebirthPerks.CapacityFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "DeepPockets").Capacity or 1
end

function RebirthPerks.TreasureFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "LuckyDigger").TreasureChance or 1
end

function RebirthPerks.CoinFactor(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "GoldenTouch").Coin or 1
end

function RebirthPerks.ExtraPetSlots(perks: { [string]: number }?): number
	return RebirthPerks.Effect(perks, "PetDen").PetSlots or 0
end

function RebirthPerks.HasSellAnywhere(perks: { [string]: number }?): boolean
	return RebirthPerks.Effect(perks, "SellAnywhere").Unlocked == true
end

function RebirthPerks.OfflineCapSeconds(perks: { [string]: number }?): number
	return (RebirthPerks.OFFLINE_CAP_HOURS + (RebirthPerks.Effect(perks, "LongNap").OfflineHours or 0)) * 3600
end

function RebirthPerks.OfflineEfficiency(perks: { [string]: number }?): number
	return RebirthPerks.OFFLINE_EFFICIENCY + (RebirthPerks.Effect(perks, "LongNap").OfflineEfficiency or 0)
end

-- Total tokens spent (for UI / analytics).
function RebirthPerks.Spent(perks: { [string]: number }?): number
	local total = 0
	for _, def in Perks do
		for i = 1, RebirthPerks.Level(perks, def.Id) do
			total += def.Costs[i]
		end
	end
	return total
end

return RebirthPerks

```

## src/shared/Config/Rebirths.luau

Original SHA-256: `7de0a9ab47f4fee63a49dde8d4cccade8505bf6034e9ee443eaa3ad8a0dbfc78`

```lua
--!strict
--[[
	Rebirths — reset for a permanent multiplier.

	Cost(n)       = coins for the NEXT rebirth (n = rebirths already done), rounded to 2
	                significant digits. v2.2: the first rebirths are cheaper (first rebirth ~35 min
	                instead of ~56-70) and climb faster, rejoining the old 4M x 3.3^n curve at
	                n = EARLY_REBIRTHS, so the late game (Core Breaker at 10 rebirths) is unchanged:
	                  n < 4 : BaseCost * EARLY_GROWTH^n      500K, 2.8M, 15M, 85M  (EARLY_GROWTH ~5.55)
	                  n >= 4: Cost(4) * CostGrowth^(n - 4)   470M, 1.6B, 5.2B, 17B, 56B, 190B ...
	                (tools/sim/economy.luau simulates it; docs/design/Rebirth.md has the numbers.)
	Multiplier(n) = 1 + MultiplierPerRebirth * n   (applies to sand per dig AND backpack capacity)
	Tokens(n)     = BaseTokens + floor(n / 2)      (tokens for the NEXT rebirth: 2, 2, 3, 3, 4 ...;
	                spent on Rebirth Perks (Config/RebirthPerks.luau) and the Rebirth Egg)

	Resets: Coins, Sand, Shovel/OwnedShovels (back to toy shovel), Backpack/OwnedBackpacks (back to
	bucket), unsold Treasures. MaxDepth is kept as a record (your hole is refilled anyway when you
	rebirth: the server teleports you to the surface; the tide refills old holes).
	Perks (RebirthService): Head Start gives a better starting shovel + coins, Keep Backpack keeps
	the backpack. RebirthPerks are never reset.
]]

local Types = require(script.Parent.Parent.Types)

local function roundSig(x: number, digits: number): number
	if x <= 0 then
		return 0
	end
	local magnitude = 10 ^ (math.floor(math.log10(x)) - digits + 1)
	return math.floor(x / magnitude + 0.5) * magnitude
end

local BASE_COST = 500_000
local EARLY_REBIRTHS = 4
local COST_GROWTH = 3.3
local LATE_BASE = 4_000_000 -- the pre-v2.2 curve (4M x 3.3^n) that rebirth 5+ still follows
local EARLY_GROWTH = (LATE_BASE * COST_GROWTH ^ EARLY_REBIRTHS / BASE_COST) ^ (1 / EARLY_REBIRTHS)
local MULTIPLIER_PER_REBIRTH = 0.5
local BASE_TOKENS = 2

local Rebirths: Types.RebirthConfig = {
	BaseCost = BASE_COST,
	CostGrowth = COST_GROWTH,
	MultiplierPerRebirth = MULTIPLIER_PER_REBIRTH,
	BaseTokens = BASE_TOKENS,
	Resets = { "Coins", "Sand", "Shovel", "OwnedShovels", "Backpack", "OwnedBackpacks", "Treasures", "Finds" },
	Keeps = {
		"Rebirths",
		"RebirthTokens",
		"MaxDepth",
		"TotalSandDug",
		"Pets",
		"PetSlots",
		"Index",
		"FindVariants",
		"DailyStreak",
		"LastDailyClaim",
		"Quests",
		"RedeemedCodes",
		"Settings",
		"Boosts",
		"PlayTime",
		"FirstJoin",
		"RebirthPerks",
		"LastOnline",
	},
	Cost = function(rebirths: number): number
		local n = math.max(rebirths, 0)
		local early = math.min(n, EARLY_REBIRTHS)
		return roundSig(BASE_COST * EARLY_GROWTH ^ early * COST_GROWTH ^ (n - early), 2)
	end,
	Multiplier = function(rebirths: number): number
		return 1 + MULTIPLIER_PER_REBIRTH * math.max(rebirths, 0)
	end,
	Tokens = function(rebirths: number): number
		return BASE_TOKENS + math.floor(math.max(rebirths, 0) / 2)
	end,
}

return Rebirths

```

## src/shared/Config/Ride.luau

Original SHA-256: `d335f6127322b3ef741fb81ef87eae83957a6b29b56d2d4f33d35952046eb466`

```lua
--!strict
--[[
	Ride — tuning for the ride-on excavator (v2.1, Ride agent). A player who owns a pet with
	PetDef.Rideable = true can press Ride (V / DPadUp / the Ride button) to spawn a full-size
	vehicle (Models/Rides.luau), sit in it, drive it around the beach and dig big chunks in front
	of it. Server: Services/RideService.luau. Client: Controllers/RideController.luau,
	UI/RideButton.luau. Physics and hole handling: see the RideService header.

	All distances in studs, speeds in studs/s, angles in radians. Expect to tune in Studio.
]]

local Ride = {
	-- Driving (client, applied through AlignPosition / AlignOrientation on the rider's machine)
	MaxSpeed = 18, -- forward top speed
	ReverseFactor = 0.6, -- reverse top speed = MaxSpeed * this
	Acceleration = 26, -- studs/s^2 towards the target speed (also braking)
	TurnRate = 1.6, -- yaw rate at full stick (~92 degrees/s)
	HoverHeight = 0.15, -- pivot (bottom of the tracks) above the ground under the tracks
	Responsiveness = 35, -- AlignPosition / AlignOrientation responsiveness
	ForceGravities = 6, -- AlignPosition MaxForce = assembly weight x this (enough to climb the deck)

	-- Area: the dig zone plus the boardwalk. The vehicle centre is clamped to
	-- x in [zone min + EdgeMargin, zone max - EdgeMargin], z in [zone sea edge + EdgeMargin, InlandMaxZ].
	EdgeMargin = 7,
	InlandMaxZ = 4, -- boardwalk deck is z -4..12; the vehicle's back stays on the deck
	SpawnMaxDistance = 40, -- the player must be this close to the ride area to call the vehicle
	-- Ground (mirrors World/Layout: BOARDWALK_Z0 = -4, DECK_TOP = SURFACE_Y + 3). On the sand the
	-- tracks follow the terrain (raycast) but never sink below SURFACE_Y: holes are bridged.
	DeckSeaEdgeZ = -4,
	DeckTop = 3, -- above Config.SURFACE_Y (visible sand + 1)
	TrackSamples = { -- model-space (x, z) points under the tracks sampled for the ground height
		Vector2.new(-3.5, -5.5),
		Vector2.new(3.5, -5.5),
		Vector2.new(-3.5, 5.5),
		Vector2.new(3.5, 5.5),
		Vector2.new(0, 0),
	},

	-- Digging
	DigAhead = 11, -- studs in front of the vehicle pivot where the bucket scoops
	MaxDigDepth = 40, -- the bucket only reaches this far below the surface (drive on to dig more)
	MinRadius = 6, -- dig radius at least this (12-stud cube, like a top shovel)
	IntervalLeniency = 0.85, -- server accepts RideDig after Dig.Interval * this (latency slack)

	-- Server anti-cheat (position checks every ValidateInterval seconds)
	ValidateInterval = 0.5,
	SpeedTolerance = 1.6, -- allowed horizontal speed = MaxSpeed * this + SpeedSlack
	SpeedSlack = 8,
	MinY = -6, -- relative to Config.SURFACE_Y (the vehicle never drives into holes)
	MaxY = 14,
	MaxStrikes = 3, -- resets in a row before the vehicle is despawned
	SeatTimeout = 3, -- despawn when the rider was never seated after this many seconds
}

return Ride

```

## src/shared/Config/Shades.luau

Original SHA-256: `c2e1ad473345b953fbc37b5e9857a253ea8a42a5c01db67aa0221e4520365884`

```lua
--!strict
--[[
	Shades — placeable shade items (owner: Survival), ordered by price. Bought once with coins
	(PlayerData.OwnedShades), placed on the beach sand, cools ANYONE standing under it.

	Radius  = horizontal studs of shade around the pole.
	Cooling = multiplier on Config.Heat.ShadeFallPerSecond (3/s): 1 -> 100..40 heat in 20 s.
	Height  = studs from the ground to the underside of the canopy (models are built to match).
	Prices sit next to the shovel ladder (GDD §4): the umbrella is the first "extra" purchase
	(~3-5 min, after the trowel / pail / spade); each tier costs ~7-10x the last.
	Look.Style picks the model builder in Models/Shades.luau.
]]
local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Shades: { Types.ShadeDef } = {
	{
		Id = "beach_umbrella",
		Name = "Beach Umbrella",
		Price = 120,
		Radius = 6,
		Cooling = 1,
		Height = 7.5,
		Description = "A trusty umbrella. Shade for you and a friend.",
		Look = { Style = "Umbrella", Color = rgb(255, 80, 90), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "striped_umbrella",
		Name = "Striped Umbrella",
		Price = 1200,
		Radius = 8,
		Cooling = 1.4,
		Height = 8,
		Description = "Extra-wide rainbow stripes. Cools faster!",
		Look = { Style = "Striped", Color = rgb(40, 170, 255), Accent = rgb(255, 225, 60) },
	},
	{
		Id = "palm_tarp",
		Name = "Palm Tarp",
		Price = 12000,
		Radius = 10,
		Cooling = 1.8,
		Height = 8.5,
		Description = "A big tarp tied between palm-wood poles. Room for the squad.",
		Look = { Style = "Tarp", Color = rgb(255, 150, 40), Accent = rgb(176, 120, 72) },
	},
	{
		Id = "party_canopy",
		Name = "Party Canopy",
		Price = 100000,
		Radius = 12,
		Cooling = 2.3,
		Height = 9,
		Description = "A pop-up party tent with bunting. Very cool. Literally.",
		Look = { Style = "Canopy", Color = rgb(90, 210, 120), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "tiki_cabana",
		Name = "Tiki Cabana",
		Price = 750000,
		Radius = 14,
		Cooling = 2.8,
		Height = 9,
		Description = "A thatched tiki hut with curtains. Island vibes.",
		Look = { Style = "Cabana", Color = rgb(225, 190, 110), Accent = rgb(255, 120, 150) },
	},
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
	},
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
	},
}

return Shades

```

## src/shared/Config/Shovels.luau

Original SHA-256: `948350c4fc51962c91c1763da7247f9e0ae645d073c9241d9f46c5400d442890`

```lua
--!strict
--[[
	Shovels — ordered by price. Shovel N+1 always unlocks the next layer (Power == that layer's
	Hardness), so depth == progress. The starter Hand Spade (Power 2) digs Dry + Wet Sand.
	Cooldown 0.5s -> 0.12s, SandMultiplier 1x -> 75x.
	Radius = half the edge of the voxel-aligned cube a dig removes (DigService rounds the edge
	Radius * 2 to whole 4-stud voxels): 2-2.8 -> 4x4x4 (starters), 3.2-4.4 -> 8x8x8,
	5-6.6 -> 12x12x12, 7.2-8 -> 16x16x16 (Core Breaker).
	Late shovels need rebirths so rebirthing is the only way to reach the Core.
	Look.Size: the first two tiers (Hand Spade, Garden Trowel) are small one-handed hand tools
	("Hand"); from the Metal Spade on every shovel is a full-size tool held with both hands.
	Balance sheet: docs/GDD.md "Economy sanity check".
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Shovels: { Types.ShovelDef } = {
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
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
	},
}

return Shovels

```

## src/shared/Config/Social.luau

Original SHA-256: `c47c3301d817da7fa9daa4bc0048376391a3704abc9a68cdc470a611cbcef051`

```lua
--!strict
--[[
	Social — tuning for status & social features (v2.2, Status & Social agent):
	nameplates, rare-find announcements, leaderboard scopes and the server dig goal.
	Read-only at runtime.
]]

export type SocialConfig = {
	Nameplate: {
		MaxDistance: number, -- studs; BillboardGui.MaxDistance
		StarsInline: number, -- up to this many rebirths show as "★★★", above it "★x12"
	},
	Announce: {
		Duration: number, -- seconds each banner stays on screen
		Gap: number, -- seconds between two banners (rate limit)
		MaxQueued: number, -- older queued announcements are dropped beyond this
	},
	Leaderboard: {
		CycleSeconds: number, -- each board flips scope this often
		WeeklyPrefix: { Coins: string, Depth: string }, -- + "_W<ISO year>_<ISO week>"
		WriteBackoffMax: number, -- seconds; a failing store is skipped for up to this long
	},
	-- Goal = round_up(max(MinSand, sum over players of max(PerPlayerSand,
	--        RewardScale(layer at the player's MaxDepth) * DigSeconds)), Round).
	-- So it grows with the player count AND with how deep the server is (a late-game digger
	-- earns ~1000x more sand per dig than a beginner, so a flat number would be trivial or
	-- impossible). Recomputed while counting; progress never resets mid-round.
	ServerGoal: {
		MinSand: number,
		PerPlayerSand: number, -- a beginner's share (~10-15 min of Dry/Wet Sand digging)
		DigSeconds: number, -- seconds of "typical" income at each player's deepest layer
		Round: number, -- goal is rounded up to a multiple of this
		EventId: string, -- event started early for everyone when the goal is reached
		EventSeconds: number, -- how long that event runs
		CooldownSeconds: number, -- after the event ends, wait this long before counting again
	},
}

local Social: SocialConfig = {
	Nameplate = {
		MaxDistance = 60,
		StarsInline = 5,
	},
	Announce = {
		Duration = 4,
		Gap = 0.6,
		MaxQueued = 4,
	},
	Leaderboard = {
		CycleSeconds = 10,
		WeeklyPrefix = { Coins = "Leaderboard_Sand", Depth = "Leaderboard_Depth" },
		WriteBackoffMax = 600,
	},
	ServerGoal = {
		MinSand = 5000,
		PerPlayerSand = 3000,
		DigSeconds = 480,
		Round = 1000,
		EventId = "GoldenHour",
		EventSeconds = 5 * 60,
		CooldownSeconds = 60,
	},
}

return Social

```

## src/shared/Config/Sounds.luau

Original SHA-256: `2479f427acb5bbb1a10d4698fce088833f2adc4c727ac2b1f7ecf2e01647135c`

```lua
--!strict
--[[
	Sounds — SOUND_IDS. Only `rbxasset://` built-ins (shipped with every Roblox client) are used;
	"" means "not set yet": skip playing it. To upgrade, upload or pick licensed audio from the
	Creator Store and paste "rbxassetid://<id>" here. Never paste ids we don't have rights to.
	Built-ins below exist in the client content folder; verify by ear in Studio.
	(swoosh.wav was removed: Studio reports it "not approved for the requester".)
]]

local Types = require(script.Parent.Parent.Types)

local function sound(id: string, volume: number, speed: number?, looped: boolean?): Types.SoundDef
	return {
		Id = id,
		Volume = volume,
		PlaybackSpeed = speed or 1,
		Looped = looped or false,
	}
end

local Sounds: { [string]: Types.SoundDef } = {
	Dig = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.6, 0.8),
	DigBlocked = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.6),
	Sell = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.2),
	Coin = sound("rbxasset://sounds/electronicpingshort.wav", 0.5, 1.6),
	Treasure = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.9),
	RareTreasure = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.7),
	Purchase = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.4),
	Error = sound("rbxasset://sounds/clickfast.wav", 0.6, 0.5),
	Click = sound("rbxasset://sounds/clickfast.wav", 0.5, 1),
	Whoosh = sound("rbxasset://sounds/action_jump.mp3", 0.5, 1.2),
	EggShake = sound("rbxasset://sounds/clickfast.wav", 0.5, 0.8),
	Hatch = sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.8),
	NewLayer = sound("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.6),
	Rebirth = sound("rbxasset://sounds/electronicpingshort.wav", 1, 0.5),
	Splash = sound("rbxasset://sounds/impact_water.mp3", 0.7, 1),
	Teleport = sound("rbxasset://sounds/action_jump.mp3", 0.6, 1.4),
	-- v3 discovery (detector beep, excavation taps, find stings)
	DetectorBeep = sound("rbxasset://sounds/electronicpingshort.wav", 0.35, 2.2),
	ExcavateHit = sound("rbxasset://sounds/clickfast.wav", 0.7, 1.3),
	ExcavatePerfect = sound("rbxasset://sounds/electronicpingshort.wav", 0.7, 1.8),
	FindEmerge = sound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.9, 0.55),
	-- Placeholders: paste licensed rbxassetid:// ids (music is not shipped as a built-in).
	MusicBeach = sound("", 0.3, 1, true),
	MusicDeep = sound("", 0.3, 1, true),
	Ambience = sound("", 0.25, 1, true),
}

return Sounds

```

## src/shared/Config/Theme.luau

Original SHA-256: `1a3e106a77704a3107beab41d7b757d7d31b8ed93362a4fdf8c84908d8f915dc`

```lua
--!strict
--[[
	Theme — v3 "chunky simulator" palette in beach colours (docs/UI_STYLE.md, binding).
	- Outlines everywhere: Stroke (#1b1b24) 3-4 px on panels/buttons, 2-3 px on text.
	- Panels: ocean-navy body (Navy -> NavyDark) with one saturated header bar; inner cards are
	  NavyCard with a dark outline. Cream Panel/PanelAlt stay for world boards (server) only.
	- Text colour carries meaning: Money green for coins, Time sky-blue for boosts/timers, Gold
	  for rare, white for neutral.
	World boards (server) share Sand..Gold/Purple/Panel/Text/Stroke, so keep those stable.
	Mobile-first: every tappable button >= MinTouchSize design px (44 real px at UI scale 0.6).
	Fonts: FredokaOne for titles/buttons/big numbers, GothamBlack for small numbers, Gotham body.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Theme: Types.ThemeDef = {
	Colors = {
		Sand = rgb(255, 222, 140),
		SandDark = rgb(222, 176, 92),
		Ocean = rgb(40, 190, 245),
		OceanDark = rgb(20, 110, 200),
		Sky = rgb(150, 225, 255),
		Sunset = rgb(255, 140, 60),
		Coral = rgb(255, 95, 125),
		Palm = rgb(70, 210, 120),
		Gold = rgb(255, 205, 40),
		Purple = rgb(170, 100, 255),
		Panel = rgb(255, 248, 230),
		PanelAlt = rgb(255, 236, 196),
		Text = rgb(255, 255, 255),
		TextDark = rgb(45, 40, 70),
		Stroke = rgb(27, 27, 36),
		Success = rgb(70, 210, 90),
		Danger = rgb(235, 60, 70),
		Warning = rgb(255, 190, 40),
		Disabled = rgb(140, 145, 160),
		Coins = rgb(255, 205, 40),
		Tokens = rgb(120, 255, 200),
		Robux = rgb(80, 205, 110),
		Navy = rgb(29, 42, 68),
		NavyDark = rgb(22, 32, 58),
		NavyCard = rgb(44, 62, 100),
		NavyCardDark = rgb(34, 49, 82),
		Money = rgb(92, 230, 92),
		Time = rgb(110, 205, 255),
		Highlight = rgb(255, 150, 40),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamBold,
		Number = Enum.Font.GothamBlack,
	},
	CornerSmall = UDim.new(0, 8),
	CornerMedium = UDim.new(0, 12),
	CornerLarge = UDim.new(0, 18),
	CornerPill = UDim.new(1, 0),
	StrokeThickness = 3,
	MinTouchSize = 74, -- design px: 74 x UI scale 0.6 = 44 real px
	TweenTime = 0.18,
}

return Theme

```

## src/shared/Config/Titles.luau

Original SHA-256: `7335fa55a454ac1a1faf069dd9431216124391083c63001f7cfb023e67120ae1`

```lua
--!strict
--[[
	Titles — overhead nameplate title earned by the deepest layer a player has ever reached
	(PlayerData.MaxDepth, kept through rebirths). Index i = Config.Layers[i]; one title per layer.
	Color: the layer colour, except where that is too dark to read over the world with a dark
	outline (then a lighter tint of the same hue). Status & Social agent (v2.2 B6a).
]]

local rgb = Color3.fromRGB

export type TitleDef = {
	LayerId: string, -- must match Config.Layers[i].Id (checked in Config/init)
	Title: string,
	Color: Color3?, -- nil: use the layer colour
}

local Titles: { TitleDef } = {
	{ LayerId = "dry_sand", Title = "Sandcastle Rookie" },
	{ LayerId = "wet_sand", Title = "Bucket Brigade" },
	{ LayerId = "shell_bed", Title = "Shell Seeker" },
	{ LayerId = "tidal_clay", Title = "Clay Crawler", Color = rgb(214, 160, 126) },
	{ LayerId = "pirate_cove", Title = "Pirate Plunderer", Color = rgb(222, 168, 110) },
	{ LayerId = "shipwreck", Title = "Wreck Diver", Color = rgb(214, 156, 104) },
	{ LayerId = "fossil_bed", Title = "Fossil Hunter" },
	{ LayerId = "bedrock", Title = "Rock Breaker", Color = rgb(184, 188, 204) },
	{ LayerId = "crystal_caverns", Title = "Crystal Miner" },
	{ LayerId = "frozen_abyss", Title = "Ice Tunneler" },
	{ LayerId = "ancient_ruins", Title = "Ruin Raider" },
	{ LayerId = "magma_chamber", Title = "Magma Diver" },
	{ LayerId = "obsidian_depths", Title = "Obsidian Delver", Color = rgb(170, 130, 240) },
	{ LayerId = "alien_hive", Title = "Hive Invader" },
	{ LayerId = "the_core", Title = "Core Breaker" },
}

return Titles

```

## src/shared/Config/Treasures.luau

Original SHA-256: `a18e66674874b9d16d96d89b6de8f46fdb6a649e67aa12701f5e360f862b1aac`

```lua
--!strict
--[[
	Treasures — found while digging. Each belongs to one layer (Layer = index in Layers.luau)
	and appears in that layer's LootTable. SellValue ~= layerBase x rarityFactor where
	layerBase = SandValue x typical shovel SandMultiplier for that layer and rarityFactor =
	Common 8, Uncommon 20, Rare 60, Epic 200, Legendary 800, Mythic 3000 (digs-worth of sand).
	Every first find is added to PlayerData.Index (the collection book).
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Treasures: { Types.TreasureDef } = {
	{
		Id = "bottle_cap",
		Name = "Bottle Cap",
		Layer = 1,
		Rarity = "Common",
		SellValue = 8,
		FlavorText = "Somebody's soda. Gross, but it's a start!",
		Look = { Color = rgb(220, 60, 60), Shape = "Cap", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "lost_flip_flop",
		Name = "Lost Flip-Flop",
		Layer = 1,
		Rarity = "Uncommon",
		SellValue = 20,
		FlavorText = "Every beach has one. Where is the other one?!",
		Look = { Color = rgb(60, 190, 255), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "cool_sunglasses",
		Name = "Cool Sunglasses",
		Layer = 1,
		Rarity = "Rare",
		SellValue = 60,
		FlavorText = "Instantly 200% cooler.",
		Look = { Color = rgb(30, 30, 40), Shape = "Box", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "seashell",
		Name = "Seashell",
		Layer = 2,
		Rarity = "Common",
		SellValue = 16,
		FlavorText = "A classic. Smells like the ocean.",
		Look = { Color = rgb(255, 200, 170), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "sand_dollar",
		Name = "Sand Dollar",
		Layer = 2,
		Rarity = "Uncommon",
		SellValue = 40,
		FlavorText = "Sadly, shops won't accept it. The sell stand will!",
		Look = { Color = rgb(240, 230, 200), Shape = "Coin", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "message_in_a_bottle",
		Name = "Message in a Bottle",
		Layer = 2,
		Rarity = "Rare",
		SellValue = 120,
		FlavorText = "'Dig deeper. The Core is real.' - A.D.",
		Look = { Color = rgb(120, 220, 180), Shape = "Bottle", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "conch_shell",
		Name = "Conch Shell",
		Layer = 3,
		Rarity = "Common",
		SellValue = 50,
		FlavorText = "Blow it to call the seagulls.",
		Look = { Color = rgb(255, 170, 150), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "glowing_pearl",
		Name = "Glowing Pearl",
		Layer = 3,
		Rarity = "Uncommon",
		SellValue = 120,
		FlavorText = "It glows a little brighter the deeper you go.",
		Look = { Color = rgb(255, 245, 255), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "giant_clam",
		Name = "Giant Clam",
		Layer = 3,
		Rarity = "Rare",
		SellValue = 360,
		FlavorText = "It's still a little grumpy about being dug up.",
		Look = { Color = rgb(170, 140, 255), Shape = "Shell", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "rusty_anchor",
		Name = "Rusty Anchor",
		Layer = 4,
		Rarity = "Common",
		SellValue = 130,
		FlavorText = "From a boat that got stuck in the mud.",
		Look = { Color = rgb(150, 90, 60), Shape = "Anchor", Material = Enum.Material.CorrodedMetal, Glow = false },
	},
	{
		Id = "pocket_watch",
		Name = "Old Pocket Watch",
		Layer = 4,
		Rarity = "Uncommon",
		SellValue = 320,
		FlavorText = "Stopped at exactly high tide.",
		Look = { Color = rgb(220, 190, 80), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "mermaid_comb",
		Name = "Mermaid's Comb",
		Layer = 4,
		Rarity = "Rare",
		SellValue = 960,
		FlavorText = "Mermaids lose these ALL the time.",
		Look = { Color = rgb(120, 240, 230), Shape = "Shard", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "gold_doubloon",
		Name = "Gold Doubloon",
		Layer = 5,
		Rarity = "Common",
		SellValue = 360,
		FlavorText = "Pirate money! Arrr.",
		Look = { Color = rgb(255, 205, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "pirate_hook",
		Name = "Pirate Hook",
		Layer = 5,
		Rarity = "Uncommon",
		SellValue = 900,
		FlavorText = "Captain Sandbeard's spare.",
		Look = { Color = rgb(190, 190, 200), Shape = "Anchor", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "treasure_map",
		Name = "Treasure Map",
		Layer = 5,
		Rarity = "Rare",
		SellValue = 2700,
		FlavorText = "The X is... below you. Way below.",
		Look = { Color = rgb(230, 200, 140), Shape = "Tablet", Material = Enum.Material.Fabric, Glow = false },
	},
	{
		Id = "pirate_chest",
		Name = "Pirate Chest",
		Layer = 5,
		Rarity = "Legendary",
		SellValue = 36000,
		FlavorText = "Sandbeard's legendary loot chest!",
		Look = { Color = rgb(150, 95, 45), Shape = "Chest", Material = Enum.Material.Wood, Glow = false },
	},
	{
		Id = "ships_wheel",
		Name = "Ship's Wheel",
		Layer = 6,
		Rarity = "Common",
		SellValue = 960,
		FlavorText = "Steer the ship! Oh wait, it sank.",
		Look = { Color = rgb(140, 90, 50), Shape = "Wheel", Material = Enum.Material.Wood, Glow = false },
	},
	{
		Id = "captains_spyglass",
		Name = "Captain's Spyglass",
		Layer = 6,
		Rarity = "Uncommon",
		SellValue = 2400,
		FlavorText = "Spot treasure from a mile away.",
		Look = { Color = rgb(200, 160, 60), Shape = "Bottle", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "cursed_skull",
		Name = "Cursed Skull",
		Layer = 6,
		Rarity = "Epic",
		SellValue = 24000,
		FlavorText = "It winks at you when nobody is looking.",
		Look = { Color = rgb(120, 255, 140), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = true },
	},
	{
		Id = "trilobite",
		Name = "Trilobite",
		Layer = 7,
		Rarity = "Common",
		SellValue = 2900,
		FlavorText = "A 500-million-year-old bug. Cute!",
		Look = { Color = rgb(140, 130, 110), Shape = "Shell", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "ammonite",
		Name = "Ammonite",
		Layer = 7,
		Rarity = "Uncommon",
		SellValue = 7200,
		FlavorText = "A spiral shell from the age of sea monsters.",
		Look = { Color = rgb(210, 170, 120), Shape = "Shell", Material = Enum.Material.Marble, Glow = false },
	},
	{
		Id = "trex_tooth",
		Name = "T-Rex Tooth",
		Layer = 7,
		Rarity = "Rare",
		SellValue = 22000,
		FlavorText = "Bigger than your hand. Imagine the smile.",
		Look = { Color = rgb(250, 245, 225), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "dino_skull",
		Name = "Dino Skull",
		Layer = 7,
		Rarity = "Legendary",
		SellValue = 290000,
		FlavorText = "The museum would pay a fortune for this.",
		Look = { Color = rgb(245, 235, 210), Shape = "Skull", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "geode",
		Name = "Geode",
		Layer = 8,
		Rarity = "Common",
		SellValue = 7700,
		FlavorText = "Boring outside, sparkly inside.",
		Look = { Color = rgb(120, 110, 130), Shape = "Orb", Material = Enum.Material.Rock, Glow = false },
	},
	{
		Id = "iron_nugget",
		Name = "Iron Nugget",
		Layer = 8,
		Rarity = "Uncommon",
		SellValue = 19000,
		FlavorText = "Heavy, shiny, and useful for shovels.",
		Look = { Color = rgb(160, 160, 170), Shape = "Shard", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "ancient_arrowhead",
		Name = "Ancient Arrowhead",
		Layer = 8,
		Rarity = "Rare",
		SellValue = 58000,
		FlavorText = "Somebody explored down here before you.",
		Look = { Color = rgb(90, 90, 100), Shape = "Shard", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "amethyst",
		Name = "Amethyst",
		Layer = 9,
		Rarity = "Common",
		SellValue = 22000,
		FlavorText = "Purple and sparkly.",
		Look = { Color = rgb(170, 90, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "sapphire",
		Name = "Sapphire",
		Layer = 9,
		Rarity = "Uncommon",
		SellValue = 55000,
		FlavorText = "Deep blue, like the ocean far above.",
		Look = { Color = rgb(40, 110, 255), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "glow_crystal",
		Name = "Glow Crystal",
		Layer = 9,
		Rarity = "Rare",
		SellValue = 160000,
		FlavorText = "This is what lights the caverns.",
		Look = { Color = rgb(140, 255, 250), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "rainbow_diamond",
		Name = "Rainbow Diamond",
		Layer = 9,
		Rarity = "Legendary",
		SellValue = 2200000,
		FlavorText = "Every colour at once!",
		Look = { Color = rgb(255, 140, 220), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "frozen_fish",
		Name = "Frozen Fish",
		Layer = 10,
		Rarity = "Common",
		SellValue = 66000,
		FlavorText = "It's been chilling for 10,000 years.",
		Look = { Color = rgb(150, 210, 255), Shape = "Box", Material = Enum.Material.Ice, Glow = false },
	},
	{
		Id = "mammoth_tusk",
		Name = "Mammoth Tusk",
		Layer = 10,
		Rarity = "Uncommon",
		SellValue = 160000,
		FlavorText = "The mammoth wants it back.",
		Look = { Color = rgb(245, 240, 220), Shape = "Bone", Material = Enum.Material.SmoothPlastic, Glow = false },
	},
	{
		Id = "ice_crown",
		Name = "Ice Crown",
		Layer = 10,
		Rarity = "Epic",
		SellValue = 1600000,
		FlavorText = "Crown of the Frost King. Never melts.",
		Look = { Color = rgb(190, 240, 255), Shape = "Crown", Material = Enum.Material.Ice, Glow = true },
	},
	{
		Id = "stone_tablet",
		Name = "Stone Tablet",
		Layer = 11,
		Rarity = "Common",
		SellValue = 190000,
		FlavorText = "Instructions for a giant shovel?",
		Look = { Color = rgb(170, 160, 140), Shape = "Tablet", Material = Enum.Material.Slate, Glow = false },
	},
	{
		Id = "golden_idol",
		Name = "Golden Idol",
		Layer = 11,
		Rarity = "Uncommon",
		SellValue = 480000,
		FlavorText = "Don't swap it with a bag of sand...",
		Look = { Color = rgb(255, 200, 50), Shape = "Skull", Material = Enum.Material.Metal, Glow = false },
	},
	{
		Id = "sun_mask",
		Name = "Sun Mask",
		Layer = 11,
		Rarity = "Rare",
		SellValue = 1400000,
		FlavorText = "The Sandlantis people worshipped the beach sun.",
		Look = { Color = rgb(255, 170, 40), Shape = "Coin", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "atlantis_crown",
		Name = "Crown of Sandlantis",
		Layer = 11,
		Rarity = "Legendary",
		SellValue = 19000000,
		FlavorText = "The crown of the lost underground city.",
		Look = { Color = rgb(255, 215, 80), Shape = "Crown", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "obsidian_shard",
		Name = "Obsidian Shard",
		Layer = 12,
		Rarity = "Common",
		SellValue = 630000,
		FlavorText = "Volcanic glass. Sharp!",
		Look = { Color = rgb(40, 30, 50), Shape = "Shard", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "fire_ruby",
		Name = "Fire Ruby",
		Layer = 12,
		Rarity = "Uncommon",
		SellValue = 1600000,
		FlavorText = "Warm to the touch. Very warm. OUCH.",
		Look = { Color = rgb(255, 40, 40), Shape = "Gem", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "dragon_egg",
		Name = "Dragon Egg",
		Layer = 12,
		Rarity = "Legendary",
		SellValue = 63000000,
		FlavorText = "Something inside is moving...",
		Look = { Color = rgb(200, 50, 30), Shape = "Egg", Material = Enum.Material.Slate, Glow = true },
	},
	{
		Id = "shadow_gem",
		Name = "Shadow Gem",
		Layer = 13,
		Rarity = "Common",
		SellValue = 2000000,
		FlavorText = "Absorbs all light around it.",
		Look = { Color = rgb(80, 40, 120), Shape = "Gem", Material = Enum.Material.Glass, Glow = false },
	},
	{
		Id = "void_pearl",
		Name = "Void Pearl",
		Layer = 13,
		Rarity = "Uncommon",
		SellValue = 4900000,
		FlavorText = "Look inside and you see stars.",
		Look = { Color = rgb(40, 20, 80), Shape = "Orb", Material = Enum.Material.Glass, Glow = true },
	},
	{
		Id = "dragon_scale",
		Name = "Ancient Dragon Scale",
		Layer = 13,
		Rarity = "Epic",
		SellValue = 49000000,
		FlavorText = "Harder than any shovel... almost.",
		Look = { Color = rgb(150, 30, 200), Shape = "Shard", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "alien_goo",
		Name = "Alien Goo",
		Layer = 14,
		Rarity = "Common",
		SellValue = 6700000,
		FlavorText = "Squishy. Do NOT eat it.",
		Look = { Color = rgb(110, 255, 120), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "ufo_part",
		Name = "UFO Part",
		Layer = 14,
		Rarity = "Uncommon",
		SellValue = 17000000,
		FlavorText = "Looks important. Probably from the engine.",
		Look = { Color = rgb(180, 190, 200), Shape = "Wheel", Material = Enum.Material.Metal, Glow = true },
	},
	{
		Id = "alien_artifact",
		Name = "Alien Artifact",
		Layer = 14,
		Rarity = "Rare",
		SellValue = 50000000,
		FlavorText = "It hums a song about the Core.",
		Look = { Color = rgb(90, 255, 200), Shape = "Tablet", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "alien_egg",
		Name = "Alien Egg",
		Layer = 14,
		Rarity = "Legendary",
		SellValue = 670000000,
		FlavorText = "Not a chicken egg. Definitely not.",
		Look = { Color = rgb(150, 255, 90), Shape = "Egg", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "core_fragment",
		Name = "Core Fragment",
		Layer = 15,
		Rarity = "Common",
		SellValue = 24000000,
		FlavorText = "A piece of the planet's golden heart.",
		Look = { Color = rgb(255, 190, 40), Shape = "Shard", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "molten_gold",
		Name = "Molten Gold",
		Layer = 15,
		Rarity = "Uncommon",
		SellValue = 60000000,
		FlavorText = "Liquid gold that never cools.",
		Look = { Color = rgb(255, 170, 0), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "heart_of_the_earth",
		Name = "Heart of the Earth",
		Layer = 15,
		Rarity = "Legendary",
		SellValue = 2400000000,
		FlavorText = "It beats once every hour.",
		Look = { Color = rgb(255, 90, 60), Shape = "Gem", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "beach_ball_of_creation",
		Name = "Beach Ball of Creation",
		Layer = 15,
		Rarity = "Mythic",
		SellValue = 9000000000,
		FlavorText = "The FIRST beach ball. Every beach began with this.",
		Look = { Color = rgb(255, 255, 255), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
	-- v3 discovery slice: Relics (rarity "Relic"). Not in any LootTable: any deposit of layer >=
	-- Layer has Config.Discovery.RELIC_CHANCE to hold one. Value = ScaledValue seconds of income.
	{
		Id = "sun_compass",
		Name = "A.D.'s Sun Compass",
		Layer = 1,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 1800,
		FlavorText = "Signed 'A.D.' on the back. The needle doesn't point north. It points DOWN.",
		Look = { Color = rgb(255, 215, 90), Shape = "Coin", Material = Enum.Material.Neon, Glow = true },
	},
	{
		Id = "tide_heart",
		Name = "Heart of the Tide",
		Layer = 3,
		Rarity = "Relic",
		SellValue = 0,
		ScaledValue = 2400,
		FlavorText = "A shell that beats like a heart. Hold it to your ear: the Core is calling.",
		Look = { Color = rgb(120, 255, 230), Shape = "Orb", Material = Enum.Material.Neon, Glow = true },
	},
}

return Treasures

```
