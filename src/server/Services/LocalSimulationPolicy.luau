--!strict
--[[
	LocalSimulationPolicy — lets Roblox Studio's "Server & Clients" test players settle adventure
	rewards, and ONLY in a LocalOnly Studio candidate. Server-only.

	Why: a local Studio test server gives its players negative UserIds (-1, -2, ...). The reward
	and trophy validation (Trophies.Rules.IsUserId) accepts real UserIds only, an integer in
	[1, 2^53], so a two-client acceptance run in the LocalOnly candidate (in-memory saves, no
	DataStores) could play the whole Spring Vault and then get BadParticipants: no outcome cards.

	How: AdventureSettlement asks Predicate() at each settlement and passes the result explicitly
	(Rewards.StageDecisions / FinalDecisions options, TrophyService SettleOptions). The shared
	modules hold no switch; nil (production, Mock, any non-candidate server) keeps the normal
	rule. Only the UserId range check is widened; every eligibility rule (points, objectives,
	ActiveSeconds, the runtime's Eligible/Connected/Left facts, receipts) applies unchanged.

	Guard, evaluated at use time (every call), ALL required:
	  * RunService:IsStudio()
	  * CandidateProfile.IsLocalOnly()          (the validated Studio-only candidate marker)
	  * DataService.StorageMode() == "LocalOnly" (not the "Mock" Studio fallback, not "DataStore")
	Accepted ids, ALL required:
	  * an integer in [Rules.LOCAL_SIM_MIN_USER_ID, -1] = [-64, -1]
	  * a Player with that UserId joined THIS server (it is here now, or it joined earlier and
	    left: a participant who left is still judged by the normal rules, Left/Disconnected).
	Ids are never remapped to real accounts and no eligibility is seeded. Saves and outboxes
	are in memory in LocalOnly; AdventureSettlement additionally never queues an outbox intent
	for a simulated id (its drain re-validation accepts real ids only).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TrophyRules = require(ReplicatedStorage.Shared.Trophies.Rules)

local CandidateProfile = require(script.Parent.CandidateProfile)
local DataService = require(script.Parent.DataService)

local LocalSimulationPolicy = {}

LocalSimulationPolicy.MIN_USER_ID = TrophyRules.LOCAL_SIM_MIN_USER_ID
LocalSimulationPolicy.MAX_USER_ID = -1

local function inRange(id: any): boolean
	return type(id) == "number"
		and id == id
		and id % 1 == 0
		and id >= LocalSimulationPolicy.MIN_USER_ID
		and id <= LocalSimulationPolicy.MAX_USER_ID
end

-- Simulated ids of Players that joined this server (real ids are never recorded).
local joined: { [number]: boolean } = {}

local function remember(player: Player)
	if inRange(player.UserId) then
		joined[player.UserId] = true
	end
end

Players.PlayerAdded:Connect(remember)
for _, player in Players:GetPlayers() do
	remember(player)
end

function LocalSimulationPolicy.IsEnabled(): boolean
	return RunService:IsStudio() and CandidateProfile.IsLocalOnly() and DataService.StorageMode() == "LocalOnly"
end

-- True only for a simulated id of a Player that joined this server, while the guard holds.
function LocalSimulationPolicy.AcceptsUserId(userId: number): boolean
	if not inRange(userId) or not LocalSimulationPolicy.IsEnabled() then
		return false
	end
	return joined[userId] == true or Players:GetPlayerByUserId(userId) ~= nil
end

-- The predicate to pass to the reward/trophy validation, or nil when the guard does not hold.
function LocalSimulationPolicy.Predicate(): ((number) -> boolean)?
	if not LocalSimulationPolicy.IsEnabled() then
		return nil
	end
	return LocalSimulationPolicy.AcceptsUserId
end

-- A simulated (non-real) UserId. Such ids are never written to a durable outbox.
function LocalSimulationPolicy.IsSimulatedId(userId: number): boolean
	return userId < 1
end

-- Frozen: no other server code can replace the guard or the predicate it hands out.
return table.freeze(LocalSimulationPolicy)
