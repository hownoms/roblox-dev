--!strict
-- Human-readable reward summaries for quests, daily rewards and products.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local RewardText = {}

function RewardText.Parts(reward: Types.Reward, maxDepth: number): { string }
	local parts = {}
	local coins = Config.ResolveCoins(reward, maxDepth)
	if coins > 0 then
		table.insert(parts, "💰 " .. Format.Abbreviate(coins))
	end
	if reward.RebirthTokens and reward.RebirthTokens > 0 then
		table.insert(
			parts,
			"🔷 " .. reward.RebirthTokens .. " Token" .. (if reward.RebirthTokens > 1 then "s" else "")
		)
	end
	if reward.Boost then
		local boost = Config.GetBoost(reward.Boost)
		local minutes = math.floor((reward.BoostSeconds or 0) / 60)
		table.insert(parts, "⚡ " .. (if boost then boost.Name else reward.Boost) .. " " .. minutes .. "m")
	end
	if reward.Pet then
		local pet = Config.GetPet(reward.Pet)
		table.insert(parts, "🐾 " .. (if pet then pet.Name else reward.Pet))
	end
	if reward.Egg then
		local egg = Config.GetEgg(reward.Egg)
		table.insert(parts, "🥚 " .. (if egg then egg.Name else reward.Egg) .. " x" .. (reward.EggCount or 1))
	end
	if reward.Rebirth then
		table.insert(parts, "♻️ Free Rebirth")
	end
	return parts
end

function RewardText.Describe(reward: Types.Reward, maxDepth: number, separator: string?): string
	return table.concat(RewardText.Parts(reward, maxDepth), separator or "  ")
end

return RewardText
