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
