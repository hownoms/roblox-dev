--!strict
--[[
	Rebirths — reset for a permanent multiplier.

	Cost(n)       = BaseCost * CostGrowth^n, rounded to 2 significant digits
	                (n = rebirths already done; cost of the NEXT rebirth).
	                4M, 13M, 44M, 140M, 470M, 1.6B, 5.2B, 17B, 56B, 190B, 610B ...
	Multiplier(n) = 1 + MultiplierPerRebirth * n   (applies to sand per dig AND backpack capacity)
	Tokens(n)     = BaseTokens + floor(n / 3)      (tokens for the NEXT rebirth; spent on the Rebirth Egg)

	Resets: Coins, Sand, Shovel/OwnedShovels (back to toy shovel), Backpack/OwnedBackpacks (back to
	bucket), unsold Treasures. MaxDepth is kept as a record (your hole is refilled anyway when you
	rebirth: the server teleports you to the surface; the tide refills old holes).
]]

local Types = require(script.Parent.Parent.Types)

local function roundSig(x: number, digits: number): number
	if x <= 0 then
		return 0
	end
	local magnitude = 10 ^ (math.floor(math.log10(x)) - digits + 1)
	return math.floor(x / magnitude + 0.5) * magnitude
end

local BASE_COST = 4_000_000
local COST_GROWTH = 3.3
local MULTIPLIER_PER_REBIRTH = 0.5
local BASE_TOKENS = 1

local Rebirths: Types.RebirthConfig = {
	BaseCost = BASE_COST,
	CostGrowth = COST_GROWTH,
	MultiplierPerRebirth = MULTIPLIER_PER_REBIRTH,
	BaseTokens = BASE_TOKENS,
	Resets = { "Coins", "Sand", "Shovel", "OwnedShovels", "Backpack", "OwnedBackpacks", "Treasures" },
	Keeps = {
		"Rebirths",
		"RebirthTokens",
		"MaxDepth",
		"TotalSandDug",
		"Pets",
		"PetSlots",
		"Index",
		"DailyStreak",
		"LastDailyClaim",
		"Quests",
		"RedeemedCodes",
		"Settings",
		"Boosts",
		"PlayTime",
		"FirstJoin",
	},
	Cost = function(rebirths: number): number
		return roundSig(BASE_COST * COST_GROWTH ^ math.max(rebirths, 0), 2)
	end,
	Multiplier = function(rebirths: number): number
		return 1 + MULTIPLIER_PER_REBIRTH * math.max(rebirths, 0)
	end,
	Tokens = function(rebirths: number): number
		return BASE_TOKENS + math.floor(math.max(rebirths, 0) / 3)
	end,
}

return Rebirths
