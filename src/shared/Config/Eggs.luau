--!strict
--[[
	Eggs — hatch pets. Coin eggs unlock when your MaxDepth reaches the layer UnlockLayer
	(Config.IsEggUnlocked). Weights are relative (they sum to 100 for readability).
	Rebirth Egg costs Rebirth Tokens. Golden Egg is Robux-only: one hatch = one purchase of
	Config.Monetization.Products[ProductKey] (Price here is the Robux suggestion).
	Luck boosts multiply the weight of non-Common pets; Triple Hatch pass hatches 3 at once.
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
		Id = "golden_egg",
		Name = "Golden Egg",
		Currency = "Robux",
		Price = 79,
		ProductKey = "GoldenEgg",
		UnlockLayer = 1,
		Pets = {
			{ PetId = "golden_seagull", Weight = 70 },
			{ PetId = "golden_turtle", Weight = 27 },
			{ PetId = "sun_dragon", Weight = 3 },
		},
		Look = { ShellColor = rgb(255, 210, 50), SpotColor = rgb(255, 255, 255), Glow = true },
	},
}

return Eggs
