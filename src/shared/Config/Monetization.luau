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
	  Prices are suggestions in Robux; the price set in Creator Hub is what players pay.
	==========================================================================================

	Pass effects are expressed as optional multiplier fields so the server can fold them in
	generically. Keys are stable API: server and UI reference passes by key, e.g.
	Config.Monetization.GamePasses.SellAnywhere.
	Design rule: everything a pass gives can be approximated by playing (boosts from quests,
	pets, rebirths). Passes make it faster/comfier, never exclusive power walls.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Monetization: Types.MonetizationConfig = {
	GamePasses = {
		VIP = {
			Id = 0,
			Name = "VIP",
			Price = 249,
			Description = "+25% sand, +25% luck, gold VIP chat tag and name, VIP-only beach lounge.",
			Color = rgb(255, 200, 40),
			SandMultiplier = 1.25,
			LuckMultiplier = 1.25,
		},
		DoubleSand = {
			Id = 0,
			Name = "2x Sand",
			Price = 299,
			Description = "Double sand from every single dig. Forever!",
			Color = rgb(255, 170, 40),
			SandMultiplier = 2,
		},
		SellAnywhere = {
			Id = 0,
			Name = "Sell Anywhere",
			Price = 149,
			Description = "Sell your sand from anywhere with one tap - even at the bottom of the hole.",
			Color = rgb(60, 200, 110),
		},
		AutoDig = {
			Id = 0,
			Name = "Auto Dig",
			Price = 199,
			Description = "+1 Pet slot & auto-swing: your character keeps digging by itself.",
			Color = rgb(60, 170, 255),
			ExtraPetSlots = 1, -- v2.1: was +1 digger slot (diggers are pets now)
		},
		Lucky = {
			Id = 0,
			Name = "Lucky Shovel",
			Price = 149,
			Description = "2x treasure luck and better pets from eggs. Forever!",
			Color = rgb(90, 230, 120),
			LuckMultiplier = 2,
		},
		TripleHatch = {
			Id = 0,
			Name = "Triple Hatch",
			Price = 99,
			Description = "Hatch 3 eggs at once.",
			Color = rgb(255, 120, 200),
		},
		ExtraPets = {
			Id = 0,
			Name = "+2 Pet Slots",
			Price = 199,
			Description = "Equip 2 more pets at the same time.",
			Color = rgb(180, 100, 255),
			ExtraPetSlots = 2,
		},
		MegaBackpack = {
			Id = 0,
			Name = "Mega Backpack",
			Price = 129,
			Description = "2x backpack capacity on every backpack. Fewer trips, more digging!",
			Color = rgb(255, 120, 60),
			CapacityMultiplier = 2,
		},
	},

	Products = {
		CoinsSmall = {
			Id = 0,
			Name = "Pile of Coins",
			Price = 25,
			Description = "5 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 300, Coins = 500 },
		},
		CoinsMedium = {
			Id = 0,
			Name = "Bag of Coins",
			Price = 99,
			Description = "25 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 1500, Coins = 2500 },
		},
		CoinsLarge = {
			Id = 0,
			Name = "Chest of Coins",
			Price = 299,
			Description = "2 hours worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 7200, Coins = 12000 },
		},
		CoinsHuge = {
			Id = 0,
			Name = "Sunken Ship of Coins",
			Price = 799,
			Description = "6 hours worth of coins at your deepest layer!",
			Grant = { ScaledCoins = 21600, Coins = 40000 },
		},
		SandBoost15 = {
			Id = 0,
			Name = "2x Sand (15 min)",
			Price = 35,
			Description = "Double sand for 15 minutes. Stacks time.",
			Grant = { Boost = "SandBoost", BoostSeconds = 900 },
		},
		LuckBoost15 = {
			Id = 0,
			Name = "2x Luck (15 min)",
			Price = 35,
			Description = "Double luck for 15 minutes. Stacks time.",
			Grant = { Boost = "LuckBoost", BoostSeconds = 900 },
		},
		SkipRebirth = {
			Id = 0,
			Name = "Skip Rebirth",
			Price = 199,
			Description = "Rebirth right now without paying the coin cost.",
			Grant = { Rebirth = true },
		},
		GoldenEgg = {
			Id = 0,
			Name = "Golden Egg",
			Price = 79,
			Description = "Hatch 1 Golden Egg (Epic or better guaranteed!).",
			Grant = { Egg = "golden_egg", EggCount = 1 },
		},
		GoldenEgg3 = {
			Id = 0,
			Name = "3 Golden Eggs",
			Price = 199,
			Description = "Hatch 3 Golden Eggs at once (save 38 Robux).",
			Grant = { Egg = "golden_egg", EggCount = 3 },
		},
		-- v2 survival (Survival agent). Granted by SurvivalService via the Main grant handler.
		CoolerPack = {
			Id = 0,
			Name = "Cooler Pack",
			Price = 29,
			Description = "10 Coconut Waters, 5 Shaved Ice and 3 Watermelon Slices. Stay cool!",
			Grant = { Consumables = { coconut_water = 10, shaved_ice = 5, watermelon_slice = 3 } },
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
