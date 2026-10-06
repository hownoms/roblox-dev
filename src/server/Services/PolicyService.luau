--!strict
--[[
	PolicyService — per-player Roblox policy (PolicyService:GetPolicyInfoForPlayerAsync).

	Roblox requires that players for whom ArePaidRandomItemsRestricted is true can't buy random
	items with Robux, or with anything bought with Robux. In this game Coins and Rebirth Tokens can
	be bought with Robux, so every egg and crate counts. For these players we hide and refuse every
	item marked PaidRandom in Config.Monetization:
	  CoinsSmall..CoinsHuge, GoldenEgg, GoldenEgg3, LuckBoost15, SkipRebirth (it grants Rebirth
	  Tokens) and the Lucky pass.
	Coin eggs stay playable with coins earned in game. Purchases that already completed are always
	honoured in ProcessReceipt, because the player has already paid.
	We never branch on country or locale. Only the policy flags are read.

	Fetching: on join, in its own thread, with 3 tries (1 s, 2 s back-off). The result is cached
	per player and published as Player attributes:
	  "PaidRandomRestricted" (bool)  the client hides PaidRandom items unless this is false
	  "PolicyLoaded" (bool)          true once a real answer arrived (false = fallback default)
	FAILURE / PENDING DEFAULT (documented choice):
	  - live servers: treat the player as RESTRICTED (the safe side for compliance). They only lose
	    access to the PaidRandom items until a later rejoin succeeds. We retry once more after
	    60 s in case the failure was transient.
	  - Studio: NOT restricted, so developers can test purchases without policy access.

	Public API:
		PolicyService.IsPaidRandomRestricted(player): boolean
		PolicyService.CanBuy(player, kind: "GamePass" | "Product", key): boolean
		PolicyService.GetInfo(player): { [string]: any }?   (raw policy table, nil until loaded)
		PolicyService.Changed: Signal<Player>
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RobloxPolicyService = game:GetService("PolicyService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)

local PolicyService = {}

PolicyService.Changed = Signal.new() :: Signal.Signal<Player>

local ATTEMPTS = 3
local LATE_RETRY_SECONDS = 60

type Entry = { Loaded: boolean, Restricted: boolean, Info: { [string]: any }? }

local cache: { [Player]: Entry } = {}

local function fallbackRestricted(): boolean
	return not RunService:IsStudio()
end

local function publish(player: Player, entry: Entry)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("PaidRandomRestricted", entry.Restricted)
	player:SetAttribute("PolicyLoaded", entry.Loaded)
end

local function fetch(player: Player): (boolean, { [string]: any }?)
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(function(): any
			return RobloxPolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(result) == "table" then
			return true, result :: { [string]: any }
		end
		if attempt < ATTEMPTS then
			task.wait(attempt)
		else
			warn("[PolicyService] policy lookup failed for " .. player.Name .. ": " .. tostring(result))
		end
	end
	return false, nil
end

local function load(player: Player, isRetry: boolean)
	local ok, info = fetch(player)
	if cache[player] == nil or player.Parent == nil then
		return -- left while we were waiting
	end
	local entry: Entry
	if ok and info then
		entry = { Loaded = true, Restricted = info.ArePaidRandomItemsRestricted == true, Info = info }
	else
		entry = { Loaded = false, Restricted = fallbackRestricted(), Info = nil }
	end
	cache[player] = entry
	publish(player, entry)
	PolicyService.Changed:Fire(player)
	if not entry.Loaded and not isRetry and entry.Restricted then
		task.delay(LATE_RETRY_SECONDS, function()
			local current = cache[player]
			if current and not current.Loaded then
				load(player, true)
			end
		end)
	end
end

-- Public API ---------------------------------------------------------------------------------------

function PolicyService.IsPaidRandomRestricted(player: Player): boolean
	local entry = cache[player]
	if not entry then
		return fallbackRestricted() -- not fetched yet: same as a failed lookup
	end
	return entry.Restricted
end

-- Can this player be offered this pass / product? false only for PaidRandom items when restricted.
function PolicyService.CanBuy(player: Player, kind: string, key: string): boolean
	if not Config.IsPaidRandom(kind, key) then
		return true
	end
	return not PolicyService.IsPaidRandomRestricted(player)
end

function PolicyService.GetInfo(player: Player): { [string]: any }?
	local entry = cache[player]
	return if entry then entry.Info else nil
end

-- Lifecycle ----------------------------------------------------------------------------------------

function PolicyService.Init() end

function PolicyService.Start() end

function PolicyService.OnPlayerAdded(player: Player)
	if cache[player] then
		return
	end
	-- pending: publish the fallback right away so the client never shows a PaidRandom item early
	local pending: Entry = { Loaded = false, Restricted = fallbackRestricted(), Info = nil }
	cache[player] = pending
	publish(player, pending)
	task.spawn(load, player, false)
end

function PolicyService.OnPlayerRemoving(player: Player)
	cache[player] = nil
end

-- Tests: re-run the lookup for a player (e.g. after changing the mock's policy answer).
function PolicyService._Reload(player: Player)
	if cache[player] and Players:GetPlayerByUserId(player.UserId) then
		load(player, true)
	end
end

return PolicyService
