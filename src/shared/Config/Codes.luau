--!strict
--[[
	Codes — redeemable via Remotes.RedeemCode(code). Matched case-insensitively and with spaces
	trimmed (Config.GetCode). One redemption per player (PlayerData.RedeemedCodes[CODE] = true).
	Flip Enabled = true and republish when a milestone hits (e.g. 1KLIKES at 1,000 likes) and
	announce it in the group/Discord — codes are the #1 reason kids join the community.
	Expires is a unix timestamp (nil = never).
]]

local Schedule = require(script.Parent.Schedule)
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
		Enabled = false, -- off: the owner skipped the Roblox group for launch (11 Oct 2026)
		Expires = nil,
		GroupOnly = true,
		Note = "Group code: enable with GROUP_ID, then post it in the Roblox group and Discord.",
	},
	{
		Code = "1KLIKES",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = false,
		Expires = nil,
		Note = "Enable when the game reaches 1,000 likes.",
	},

	-- Content calendar codes (Config/Calendar.luau): live from the drop's first day (Starts) to
	-- the end of its last day (Expires). codes_off turns one off; codes_on can't move the dates.
	{
		Code = "HARVEST",
		Reward = { Egg = "cornucopia_egg", EggCount = 1, Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Starts = Schedule.Utc(2026, 11, 26),
		Expires = Schedule.Utc(2026, 12, 7) - 1,
		Note = "Harvest Dig (26 Nov - 6 Dec): one free Cornucopia Egg hatch + Sand Boost.",
	},
	{
		Code = "SNOWDAY",
		Reward = { Egg = "gift_egg", EggCount = 1, Boost = "LuckBoost", BoostSeconds = 900 },
		Enabled = true,
		Starts = Schedule.Utc(2026, 12, 12),
		Expires = Schedule.Utc(2027, 1, 5) - 1,
		Note = "Winter Beach (12 Dec - 4 Jan): one free Gift Egg hatch + Luck Boost.",
	},
	{
		Code = "HAPPY2027",
		Reward = { ScaledCoins = 600, RebirthTokens = 1 },
		Enabled = true,
		Starts = Schedule.Utc(2026, 12, 31),
		Expires = Schedule.Utc(2027, 1, 4) - 1,
		Note = "New Year (31 Dec - 3 Jan): ~10 min of income + 1 Rebirth Token.",
	},
	{
		Code = "LANTERN",
		Reward = { Egg = "lantern_egg", EggCount = 1, Boost = "CoinBoost", BoostSeconds = 900 },
		Enabled = true,
		Starts = Schedule.Utc(2027, 2, 6),
		Expires = Schedule.Utc(2027, 2, 21) - 1,
		Note = "Lanterns & Hearts (6 - 20 Feb): one free Lantern Egg hatch + Coin Boost.",
	},
	{
		Code = "LUCKYDIG",
		Reward = { Egg = "clover_egg", EggCount = 1, Boost = "LuckBoost", BoostSeconds = 900 },
		Enabled = true,
		Starts = Schedule.Utc(2027, 3, 12),
		Expires = Schedule.Utc(2027, 3, 23) - 1,
		Note = "Lucky Dig (12 - 22 Mar): one free Clover Egg hatch + Luck Boost.",
	},
	{
		Code = "SPRING",
		Reward = { Egg = "pastel_egg", EggCount = 1, Boost = "SandBoost", BoostSeconds = 900 },
		Enabled = true,
		Starts = Schedule.Utc(2027, 3, 26),
		Expires = Schedule.Utc(2027, 4, 13) - 1,
		Note = "Spring Hatch (26 Mar - 12 Apr): one free Pastel Egg hatch + Sand Boost.",
	},
}

return Codes
