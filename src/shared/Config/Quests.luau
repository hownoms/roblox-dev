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
