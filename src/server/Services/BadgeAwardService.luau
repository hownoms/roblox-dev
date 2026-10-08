--!strict
--[[
	BadgeAwardService — awards Roblox badges from Config.Badges when PlayerData crosses a
	milestone (first dig, first pet, reaching a layer, rebirths, a Mythic+ find, a completed
	layer Index, a daily streak). Badges with Id 0 are skipped.
	Each badge is attempted at most once per player per session; BadgeService itself ignores
	repeat awards across sessions.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

local BadgeAwardService = {}

local RELEVANT_KEYS =
	{ TotalSandDug = true, Pets = true, MaxDepth = true, Rebirths = true, Index = true, DailyStreak = true }

local attempted: { [Player]: { [string]: boolean } } = {}

local function layerDepth(name: string?): number?
	for _, layer in Config.Layers do
		if layer.Name == name then
			return layer.DepthStart
		end
	end
	return nil
end

-- Treasures per layer, excluding Relics (matches the Index panel's "x / y found").
local layerTreasures: { [number]: { string } } = {}
for _, treasure in Config.Treasures do
	if treasure.Rarity ~= "Relic" then
		layerTreasures[treasure.Layer] = layerTreasures[treasure.Layer] or {}
		table.insert(layerTreasures[treasure.Layer], treasure.Id)
	end
end

local function rarityOrder(name: string?): number
	local rarity = if name then Config.GetRarity(name) else nil
	return if rarity then rarity.Order else math.huge
end

local function foundRarity(data: Types.PlayerData, minOrder: number): boolean
	for _, treasure in Config.Treasures do
		if data.Index[treasure.Id] and rarityOrder(treasure.Rarity) >= minOrder then
			return true
		end
	end
	return false
end

local function completedAnyLayer(data: Types.PlayerData): boolean
	for _, ids in layerTreasures do
		local all = true
		for _, id in ids do
			if not data.Index[id] then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	return false
end

local function earned(badge: any, data: Types.PlayerData): boolean
	if badge.Kind == "FirstDig" then
		return data.TotalSandDug > 0
	elseif badge.Kind == "FirstPet" then
		return next(data.Pets) ~= nil
	elseif badge.Kind == "ReachLayer" then
		local depth = layerDepth(badge.Layer)
		return depth ~= nil and data.MaxDepth >= depth
	elseif badge.Kind == "Rebirth" then
		return data.Rebirths >= (badge.Count or 1)
	elseif badge.Kind == "FindRarity" then
		return foundRarity(data, rarityOrder(badge.Rarity))
	elseif badge.Kind == "CompleteLayer" then
		return completedAnyLayer(data)
	elseif badge.Kind == "DailyStreak" then
		return data.DailyStreak >= (badge.Count or 7)
	end
	return false
end

local function check(player: Player)
	local data = DataService.Get(player)
	local tried = attempted[player]
	if not data or not tried then
		return
	end
	for _, badge in Config.Badges do
		if badge.Id ~= 0 and not tried[badge.Key] and earned(badge, data :: Types.PlayerData) then
			tried[badge.Key] = true
			task.spawn(function()
				local ok, err = pcall(function()
					if not BadgeService:UserHasBadgeAsync(player.UserId, badge.Id) then
						BadgeService:AwardBadge(player.UserId, badge.Id)
					end
				end)
				if not ok then
					warn("[BadgeAwardService] " .. badge.Key .. ": " .. tostring(err))
				end
			end)
		end
	end
end

function BadgeAwardService.OnPlayerAdded(player: Player)
	attempted[player] = {}
end

function BadgeAwardService.OnPlayerRemoving(player: Player)
	attempted[player] = nil
end

function BadgeAwardService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		attempted[player] = attempted[player] or {}
		check(player)
	end)
	DataService.Changed:Connect(function(player: Player, keys: { string })
		for _, key in keys do
			if RELEVANT_KEYS[key] then
				check(player)
				return
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		attempted[player] = attempted[player] or {}
		check(player)
	end
end

return BadgeAwardService
