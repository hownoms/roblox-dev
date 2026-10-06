--!strict
--[[
	Rebirths — reset for a permanent multiplier.

	Cost(n)       = coins for the NEXT rebirth (n = rebirths already done), rounded to 2
	                significant digits. v2.2: the first rebirths are cheaper (first rebirth ~35 min
	                instead of ~56-70) and climb faster, rejoining the old 4M x 3.3^n curve at
	                n = EARLY_REBIRTHS, so the late game (Core Breaker at 10 rebirths) is unchanged:
	                  n < 4 : BaseCost * EARLY_GROWTH^n      500K, 2.8M, 15M, 85M  (EARLY_GROWTH ~5.55)
	                  n >= 4: Cost(4) * CostGrowth^(n - 4)   470M, 1.6B, 5.2B, 17B, 56B, 190B ...
	                (tools/sim/economy.luau simulates it; docs/design/Rebirth.md has the numbers.)
	Multiplier(n) = 1 + MultiplierPerRebirth * n   (applies to sand per dig AND backpack capacity)
	Tokens(n)     = BaseTokens + floor(n / 2)      (tokens for the NEXT rebirth: 2, 2, 3, 3, 4 ...;
	                spent on Rebirth Perks (Config/RebirthPerks.luau) and the Rebirth Egg)

	Resets: Coins, Sand, Shovel/OwnedShovels (back to toy shovel), Backpack/OwnedBackpacks (back to
	bucket), unsold Treasures. MaxDepth is kept as a record (your hole is refilled anyway when you
	rebirth: the server teleports you to the surface; the tide refills old holes).
	Perks (RebirthService): Head Start gives a better starting shovel + coins, Keep Backpack keeps
	the backpack. RebirthPerks are never reset.
]]

local Types = require(script.Parent.Parent.Types)

local function roundSig(x: number, digits: number): number
	if x <= 0 then
		return 0
	end
	local magnitude = 10 ^ (math.floor(math.log10(x)) - digits + 1)
	return math.floor(x / magnitude + 0.5) * magnitude
end

local BASE_COST = 500_000
local EARLY_REBIRTHS = 4
local COST_GROWTH = 3.3
local LATE_BASE = 4_000_000 -- the pre-v2.2 curve (4M x 3.3^n) that rebirth 5+ still follows
local EARLY_GROWTH = (LATE_BASE * COST_GROWTH ^ EARLY_REBIRTHS / BASE_COST) ^ (1 / EARLY_REBIRTHS)
local MULTIPLIER_PER_REBIRTH = 0.5
local BASE_TOKENS = 2

local Rebirths: Types.RebirthConfig = {
	BaseCost = BASE_COST,
	CostGrowth = COST_GROWTH,
	MultiplierPerRebirth = MULTIPLIER_PER_REBIRTH,
	BaseTokens = BASE_TOKENS,
	Resets = { "Coins", "Sand", "Shovel", "OwnedShovels", "Backpack", "OwnedBackpacks", "Treasures", "Finds" },
	Keeps = {
		"Rebirths",
		"RebirthTokens",
		"MaxDepth",
		"TotalSandDug",
		"Pets",
		"PetSlots",
		"Index",
		"FindVariants",
		"DailyStreak",
		"LastDailyClaim",
		"Quests",
		"RedeemedCodes",
		"Settings",
		"Boosts",
		"PlayTime",
		"FirstJoin",
		"RebirthPerks",
		"LastOnline",
	},
	Cost = function(rebirths: number): number
		local n = math.max(rebirths, 0)
		local early = math.min(n, EARLY_REBIRTHS)
		return roundSig(BASE_COST * EARLY_GROWTH ^ early * COST_GROWTH ^ (n - early), 2)
	end,
	Multiplier = function(rebirths: number): number
		return 1 + MULTIPLIER_PER_REBIRTH * math.max(rebirths, 0)
	end,
	Tokens = function(rebirths: number): number
		return BASE_TOKENS + math.floor(math.max(rebirths, 0) / 2)
	end,
}

return Rebirths
