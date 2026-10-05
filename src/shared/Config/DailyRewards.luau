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
