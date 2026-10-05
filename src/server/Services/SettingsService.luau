--!strict
--[[
	SettingsService — owns the SetSetting(key, value) remote.

	Three kinds of keys:
	  1. Actions (not persisted), registered by other services:  RegisterAction(key, fn)
	       "SellNow"  (EconomyService) sell from anywhere — needs the SellAnywhere pass
	  2. Validated settings, registered by other services:        RegisterValidator(key, fn)
	       "AutoDig"  (DigService) boolean — needs the AutoDig pass to turn on
	  3. Generic client preferences (persisted in PlayerData.Settings): any key matching
	     ^[A-Za-z][A-Za-z0-9_]*$ up to 32 chars, value = boolean | finite number | string (<= 64
	     chars) | nil (clears). At most MAX_CLIENT_KEYS keys. Reserved prefixes "FTUE_" and
	     "Server_" are server-only. Examples the UI may use: Music, Sounds, TutorialStep,
	     TutorialDone, HidePets, LowGraphics.

	Public API:
		SettingsService.RegisterAction(key, fn(player, value))
		SettingsService.RegisterValidator(key, fn(player, value) -> (ok, storedValue))
		SettingsService.Get(player, key): any
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

export type Action = (player: Player, value: any) -> ()
export type Validator = (player: Player, value: any) -> (boolean, any)

local MAX_CLIENT_KEYS = 40
local RESERVED_PREFIXES = { "FTUE_", "Server_" }

local SettingsService = {}

local actions: { [string]: Action } = {}
local validators: { [string]: Validator } = {}

function SettingsService.RegisterAction(key: string, fn: Action)
	actions[key] = fn
end

function SettingsService.RegisterValidator(key: string, fn: Validator)
	validators[key] = fn
end

function SettingsService.Get(player: Player, key: string): any
	local data = DataService.Get(player)
	return if data then data.Settings[key] else nil
end

local function isReserved(key: string): boolean
	for _, prefix in RESERVED_PREFIXES do
		if string.sub(key, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function genericValue(value: any): (boolean, any)
	local t = type(value)
	if value == nil or t == "boolean" then
		return true, value
	elseif t == "number" then
		return Net.IsNumber(value), value
	elseif t == "string" then
		return #value <= 64, value
	end
	return false, nil
end

local function onSetSetting(player: Player, key: any, value: any)
	if not Net.IsString(key, 32) then
		return
	end
	local action = actions[key]
	if action then
		action(player, value)
		return
	end

	local maybeData = DataService.Get(player)
	if not maybeData then
		return
	end
	local data = maybeData :: Types.PlayerData

	local ok, stored
	local validator = validators[key]
	if validator then
		ok, stored = validator(player, value)
	else
		if not string.match(key, "^[%a][%w_]*$") or isReserved(key) then
			return
		end
		ok, stored = genericValue(value)
		if ok and data.Settings[key] == nil and stored ~= nil and TableUtil.Count(data.Settings) >= MAX_CLIENT_KEYS then
			ok = false
		end
	end
	if not ok or data.Settings[key] == stored then
		return
	end
	data.Settings[key] = stored
	DataService.MarkDirty(player, "Settings")
end

function SettingsService.Init()
	Net.On("SetSetting", onSetSetting, { Rate = 15, Window = 1 })
end

function SettingsService.Start() end

return SettingsService
