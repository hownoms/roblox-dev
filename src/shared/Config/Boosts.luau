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
}

return Boosts
