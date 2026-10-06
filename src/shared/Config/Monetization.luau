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
			Id = 0,
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
			Id = 0,
			Name = "2x Sand",
			Price = 399,
			Description = "Double sand from every single dig. Forever!",
			Color = rgb(255, 170, 40),
			SandMultiplier = 2,
		},
		SellAnywhere = {
			Id = 0,
			Name = "Sell Anywhere",
			Price = 249,
			-- v2.2: also earnable for free with the Sell Anywhere rebirth perk (Config.RebirthPerks)
			Description = "Sell your sand from anywhere with one tap - even at the bottom of the hole. Get it now, or unlock it for free later with Rebirth Perks!",
			Color = rgb(60, 200, 110),
		},
		AutoDig = {
			Id = 0,
			Name = "Auto Dig",
			Price = 299,
			Description = "+1 Pet slot & auto-swing: your character keeps digging by itself.",
			Color = rgb(60, 170, 255),
			ExtraPetSlots = 1, -- v2.1: was +1 digger slot (diggers are pets now)
		},
		-- v2.3: replaces the Lucky Shovel pass (removed: paid luck). Deterministic speed only.
		FastDig = {
			Id = 0,
			Name = "Turbo Shovel",
			Price = 249,
			Description = "Dig 25% faster with every shovel. Forever!",
			Color = rgb(60, 190, 255),
			SpeedMultiplier = 1.25,
		},
		TripleHatch = {
			Id = 0,
			Name = "Triple Hatch",
			Price = 249,
			Description = "Hatch 3 eggs at once.",
			Color = rgb(255, 120, 200),
		},
		ExtraPets = {
			Id = 0,
			Name = "+2 Pet Slots",
			Price = 349,
			Description = "Equip 2 more pets at the same time.",
			Color = rgb(180, 100, 255),
			ExtraPetSlots = 2,
		},
		MegaBackpack = {
			Id = 0,
			Name = "Mega Backpack",
			Price = 299,
			Description = "2x backpack capacity on every backpack. Fewer trips, more digging!",
			Color = rgb(255, 120, 60),
			CapacityMultiplier = 2,
		},
	},

	Products = {
		CoinsSmall = {
			Id = 0,
			Name = "Pile of Coins",
			Price = 49,
			Description = "5 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 300, Coins = 500 },
			PaidRandom = true,
		},
		CoinsMedium = {
			Id = 0,
			Name = "Bag of Coins",
			Price = 149,
			Description = "25 minutes worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 1500, Coins = 2500 },
			PaidRandom = true,
		},
		CoinsLarge = {
			Id = 0,
			Name = "Chest of Coins",
			Price = 399,
			Description = "2 hours worth of coins at your deepest layer.",
			Grant = { ScaledCoins = 7200, Coins = 12000 },
			PaidRandom = true,
		},
		CoinsHuge = {
			Id = 0,
			Name = "Sunken Ship of Coins",
			Price = 999,
			Description = "6 hours worth of coins at your deepest layer!",
			Grant = { ScaledCoins = 21600, Coins = 40000 },
			PaidRandom = true,
		},
		SandBoost15 = {
			Id = 0,
			Name = "2x Sand (15 min)",
			Price = 49,
			Description = "Double sand for 15 minutes. Stacks time.",
			Grant = { Boost = "SandBoost", BoostSeconds = 900 },
		},
		SkipRebirth = {
			Id = 0,
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
