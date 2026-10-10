--!strict
--[[
	CandidateProfile — decides, once and before any service starts, how this server stores data.

	  Production  no ServerScriptService.ProductionCandidate. The normal game; nothing changes.
	  LocalOnly   a valid Studio-only review candidate (below). Player saves, both reward outboxes,
	              purchase history and the ordered leaderboards live in memory; StorageGate refuses
	              every storage acquisition or request, so nothing durable is read or written.
	              AdventureFlags takes the candidate's Flags. Rewards are a local simulation.
	  Refused     the marker exists but something is wrong. FAIL CLOSED: Main starts nothing.

	The marker (stamped by the Studio installer, never mapped by default.project.json):
	  ServerScriptService.ProductionCandidate   Folder
	    attribute ProductionCandidate = true
	    attribute AuthorizedPlace     = "<place file name containing Expansion1Review>"
	    ModuleScript CandidateConfig  returns exactly
	      { Authorization = "Expansion1Review", Storage = "LocalOnly",
	        Flags = { SpringVault = bool, AdventureRewards = bool, BroadwaveOrdinary = bool } }
	LocalOnly needs ALL of: RunService:IsStudio(), RunService:IsServer(), game.PlaceId == 0,
	game.GameId == 0, and the marker exactly as above (no unknown config or flag keys). The
	environment is checked before the config module is required (pcall'd), so a published or
	saved-to-Roblox place never runs the candidate config at all.

	Resolved at first require and cached; Main requires this first (after its duplicate guard).

	Public API:
		CandidateProfile.Mode(): "Production" | "LocalOnly" | "Refused"
		CandidateProfile.IsLocalOnly(): boolean
		CandidateProfile.Refusal(): string?            reason, only when Refused
		CandidateProfile.Flags(): { [string]: boolean }?   frozen copy, only when LocalOnly
		CandidateProfile.Manifest(): { Mode, Reason, PlaceId, GameId, IsStudio, AuthorizedPlace,
		                               Flags, Storage = StorageGate.Counters() }
		CandidateProfile._Reset()                      tests only: forget the cached resolution
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

export type Mode = string -- "Production" | "LocalOnly" | "Refused"

local MARKER_NAME = "ProductionCandidate"
local CONFIG_NAME = "CandidateConfig"
local AUTHORIZATION = "Expansion1Review"
local STORAGE = "LocalOnly"
local FLAG_KEYS = { "SpringVault", "AdventureRewards", "BroadwaveOrdinary" }
local CONFIG_KEYS = { Authorization = true, Storage = true, Flags = true }

type Resolution = {
	Mode: Mode,
	Reason: string?,
	AuthorizedPlace: string?,
	Flags: { [string]: boolean }?,
}

local CandidateProfile = {}

local resolved: Resolution? = nil

local function refuse(reason: string, authorizedPlace: string?): Resolution
	return { Mode = "Refused", Reason = reason, AuthorizedPlace = authorizedPlace, Flags = nil }
end

-- Validates the candidate Flags table: exactly the three known keys, all booleans.
local function readFlags(value: any): ({ [string]: boolean }?, string?)
	if type(value) ~= "table" then
		return nil, "CandidateConfig.Flags is not a table"
	end
	for key in value do
		if type(key) ~= "string" or not table.find(FLAG_KEYS, key) then
			return nil, "CandidateConfig.Flags has unknown key " .. tostring(key)
		end
	end
	local flags: { [string]: boolean } = {}
	for _, key in FLAG_KEYS do
		local flag = value[key]
		if type(flag) ~= "boolean" then
			return nil, "CandidateConfig.Flags." .. key .. " is not a boolean"
		end
		flags[key] = flag
	end
	return flags, nil
end

local function resolve(): Resolution
	local marker = ServerScriptService:FindFirstChild(MARKER_NAME)
	if marker == nil then
		return { Mode = "Production", Reason = nil, AuthorizedPlace = nil, Flags = nil }
	end
	local folder = marker :: Instance
	-- environment first: never run the candidate config outside a local Studio server
	if not RunService:IsStudio() then
		return refuse("not running in Studio")
	end
	if not RunService:IsServer() then
		return refuse("not a server")
	end
	if game.PlaceId ~= 0 then
		return refuse("PlaceId is " .. tostring(game.PlaceId) .. ", expected 0 (unpublished place)")
	end
	if game.GameId ~= 0 then
		return refuse("GameId is " .. tostring(game.GameId) .. ", expected 0 (unpublished place)")
	end
	if not folder:IsA("Folder") then
		return refuse(MARKER_NAME .. " is a " .. folder.ClassName .. ", expected a Folder")
	end
	if folder:GetAttribute(MARKER_NAME) ~= true then
		return refuse(MARKER_NAME .. " attribute is not true")
	end
	local place = folder:GetAttribute("AuthorizedPlace")
	if type(place) ~= "string" then
		return refuse("AuthorizedPlace attribute is missing")
	end
	if not string.find(place, AUTHORIZATION, 1, true) then
		return refuse("AuthorizedPlace " .. place .. " is not an " .. AUTHORIZATION .. " place", place)
	end
	local module = folder:FindFirstChild(CONFIG_NAME)
	if module == nil or not module:IsA("ModuleScript") then
		return refuse(CONFIG_NAME .. " ModuleScript is missing", place)
	end
	local ok, config = pcall(require, module :: ModuleScript)
	if not ok then
		return refuse(CONFIG_NAME .. " failed to load: " .. tostring(config), place)
	end
	if type(config) ~= "table" then
		return refuse(CONFIG_NAME .. " did not return a table", place)
	end
	for key in config do
		if type(key) ~= "string" or not CONFIG_KEYS[key] then
			return refuse(CONFIG_NAME .. " has unknown key " .. tostring(key), place)
		end
	end
	if config.Authorization ~= AUTHORIZATION then
		return refuse(CONFIG_NAME .. ".Authorization is not " .. AUTHORIZATION, place)
	end
	if config.Storage ~= STORAGE then
		return refuse(CONFIG_NAME .. ".Storage is " .. tostring(config.Storage) .. ", expected " .. STORAGE, place)
	end
	local flags, flagProblem = readFlags(config.Flags)
	if not flags then
		return refuse(flagProblem or "CandidateConfig.Flags is invalid", place)
	end
	return { Mode = "LocalOnly", Reason = nil, AuthorizedPlace = place, Flags = table.freeze(flags) }
end

local function current(): Resolution
	local value = resolved
	if value == nil then
		value = resolve()
		resolved = value
	end
	return value :: Resolution
end

function CandidateProfile.Mode(): Mode
	return current().Mode
end

function CandidateProfile.IsLocalOnly(): boolean
	return current().Mode == "LocalOnly"
end

function CandidateProfile.Refusal(): string?
	local value = current()
	return if value.Mode == "Refused" then value.Reason else nil
end

function CandidateProfile.Flags(): { [string]: boolean }?
	local value = current()
	if value.Mode ~= "LocalOnly" or value.Flags == nil then
		return nil
	end
	return table.freeze(table.clone(value.Flags :: { [string]: boolean }))
end

function CandidateProfile.Manifest(): { [string]: any }
	local value = current()
	-- lazy: StorageGate requires this module
	local StorageGate = require(script.Parent.StorageGate) :: any
	return {
		Mode = value.Mode,
		Reason = value.Reason,
		PlaceId = game.PlaceId,
		GameId = game.GameId,
		IsStudio = RunService:IsStudio(),
		AuthorizedPlace = value.AuthorizedPlace,
		Flags = CandidateProfile.Flags(),
		Storage = StorageGate.Counters(),
	}
end

-- Tests only: the next call resolves the marker again.
function CandidateProfile._Reset()
	resolved = nil
end

current()

return CandidateProfile
