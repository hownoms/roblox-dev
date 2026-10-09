--!strict
--[[
	TrophyData — the narrow adapter between trophy code and the existing save system.

	There is no second save system: trophy fields are ordinary top-level PlayerData keys inside
	the same session-locked DataService record ("Player_<UserId>" in Config.DATASTORE_NAME).
	They are saved by DataService's normal autosave / leave / BindToClose paths and replicate
	to the owner through the existing DataChanged deltas.

	Why this works without editing DataService: DataService.sanitize runs TableUtil.Reconcile,
	which keeps keys the template does not know, and saveAsync writes a deep copy of the whole
	PlayerData. Older servers (e.g. published v17) therefore carry these keys through untouched.
	RebirthService only resets Config.Rebirths.Resets, which does not include them.

	Every read goes through Get(), which runs the idempotent Rules.Migrate once per loaded save
	table, so callers always see well-formed trophy fields even before the proposed DataVersion 4
	migration hook is wired (docs/TROPHY_INTEGRATION.md).

	Mutations are synchronous (no yields inside the callback), so a save snapshot can never
	capture half a settlement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Trophies.Rules)
local DataService = require(script.Parent.DataService)

local TrophyData = {}

TrophyData.KEYS = table.freeze({ "TrophyRecords", "CampLayout", "RewardReceipts" })

-- Save tables already migrated in this server (weak: a released save is collected).
local migrated: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

TrophyData.PlayerLoaded = DataService.PlayerLoaded

-- The player's live save table with trophy fields guaranteed, or nil if not loaded.
function TrophyData.Get(player: Player): { [string]: any }?
	local data = DataService.Get(player) :: any
	if data == nil then
		return nil
	end
	if not migrated[data] then
		migrated[data] = true
		if Rules.Migrate(data, os.time()) then
			DataService.MarkDirty(player, table.unpack(TrophyData.KEYS))
		end
	end
	return data
end

function TrophyData.IsLoaded(player: Player): boolean
	return DataService.IsLoaded(player)
end

-- Runs fn(data) synchronously on the live save and replicates the trophy keys.
-- fn must not yield. Returns false when the player's data is not loaded.
function TrophyData.Mutate(player: Player, fn: ({ [string]: any }) -> ()): boolean
	if TrophyData.Get(player) == nil then
		return false
	end
	return DataService.Mutate(player, TrophyData.KEYS :: any, function(data)
		fn(data :: any)
	end)
end

-- Asks DataService to write the save now instead of waiting for the next autosave. Does not
-- yield the caller. DataService serializes saves, so this cannot race the leave save.
function TrophyData.RequestSave(player: Player)
	task.spawn(DataService.SaveAsync, player)
end

return TrophyData
