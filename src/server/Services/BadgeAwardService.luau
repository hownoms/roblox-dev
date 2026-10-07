--!strict
--[[
	BadgeAwardService — awards Roblox badges from Config.Badges when PlayerData crosses a
	milestone (first dig, first pet, reaching a layer, rebirths). Badges with Id 0 are skipped.
	Each badge is awarded at most once per player per session; BadgeService itself ignores
	repeat awards across sessions. A failed BadgeService call (throttling, outage) is retried
	on the next relevant change after RETRY_DELAYS[n] seconds, up to #RETRY_DELAYS times.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

local BadgeAwardService = {}

local RELEVANT_KEYS = { TotalSandDug = true, Pets = true, MaxDepth = true, Rebirths = true }

BadgeAwardService.RETRY_DELAYS = { 30, 120, 600 }

local attempted: { [Player]: { [string]: boolean } } = {}
local failures: { [Player]: { [string]: { Count: number, RetryAt: number } } } = {}

local function layerDepth(name: string?): number?
	for _, layer in Config.Layers do
		if layer.Name == name then
			return layer.DepthStart
		end
	end
	return nil
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
	end
	return false
end

local function check(player: Player)
	local data = DataService.Get(player)
	local tried = attempted[player]
	local failed = failures[player]
	if not data or not tried or not failed then
		return
	end
	local now = os.clock()
	for _, badge in Config.Badges do
		local failure = failed[badge.Key]
		local waiting = failure ~= nil and now < failure.RetryAt
		if badge.Id ~= 0 and not tried[badge.Key] and not waiting and earned(badge, data :: Types.PlayerData) then
			tried[badge.Key] = true
			task.spawn(function()
				local ok, err = pcall(function()
					if not BadgeService:UserHasBadgeAsync(player.UserId, badge.Id) then
						BadgeService:AwardBadge(player.UserId, badge.Id)
					end
				end)
				if ok then
					if failures[player] then
						failures[player][badge.Key] = nil
					end
					return
				end
				local count = (if failure then failure.Count else 0) + 1
				local delay = BadgeAwardService.RETRY_DELAYS[count]
				warn(
					"[BadgeAwardService] "
						.. badge.Key
						.. ": "
						.. tostring(err)
						.. (if delay then " (retrying in " .. delay .. " s)" else " (giving up this session)")
				)
				if delay and attempted[player] and failures[player] then
					attempted[player][badge.Key] = nil
					failures[player][badge.Key] = { Count = count, RetryAt = os.clock() + delay }
				end
			end)
		end
	end
end

function BadgeAwardService.OnPlayerAdded(player: Player)
	attempted[player] = {}
	failures[player] = {}
end

function BadgeAwardService.OnPlayerRemoving(player: Player)
	attempted[player] = nil
	failures[player] = nil
end

function BadgeAwardService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		attempted[player] = attempted[player] or {}
		failures[player] = failures[player] or {}
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
		failures[player] = failures[player] or {}
		check(player)
	end
end

return BadgeAwardService
