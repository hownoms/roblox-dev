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
